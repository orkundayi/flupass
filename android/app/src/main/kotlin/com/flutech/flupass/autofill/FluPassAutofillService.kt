package com.flutech.flupass.autofill

import android.app.PendingIntent
import android.app.assist.AssistStructure
import android.content.Intent
import android.os.Build
import android.os.CancellationSignal
import android.service.autofill.AutofillService
import android.service.autofill.Dataset
import android.service.autofill.FillCallback
import android.service.autofill.FillRequest
import android.service.autofill.FillResponse
import android.service.autofill.InlinePresentation
import android.service.autofill.SaveCallback
import android.service.autofill.SaveRequest
import android.view.autofill.AutofillValue
import android.widget.RemoteViews
import android.widget.inline.InlinePresentationSpec
import androidx.annotation.RequiresApi
import com.flutech.flupass.MainActivity
import com.flutech.flupass.R

class FluPassAutofillService : AutofillService() {
    private val dataStore by lazy { AutofillDataStore(this) }

    override fun onFillRequest(
        request: FillRequest,
        cancellationSignal: CancellationSignal,
        callback: FillCallback,
    ) {
        val contexts = request.fillContexts
        if (contexts.isEmpty()) {
            callback.onSuccess(null)
            return
        }
        val structure: AssistStructure = contexts.last().structure
        val fieldIds = AutofillStructureParser(structure).parseCredentialFields()

        if (fieldIds.usernameId == null && fieldIds.passwordId == null) {
            callback.onSuccess(null)
            return
        }

        val allEntries = dataStore.loadCredentials()
        val requireBiometric = dataStore.isBiometricEnabled &&
            BiometricHelper.canDeviceUseBiometric(this)

        val domainMatches = filterEntriesByDomain(allEntries, fieldIds.webDomain)
        val primaryEntries = if (domainMatches.isNotEmpty()) domainMatches else allEntries

        val responseBuilder = FillResponse.Builder()
        val inlineConfig = createInlineConfig(request)
        var inlineUsed = 0
        var datasetsAdded = 0

        primaryEntries
            .take(MAX_RESPONSE_DATASETS)
            .forEach { entry ->
                val presentation = AutofillUiFactory.createDatasetPresentation(this, entry)
                val datasetBuilder = Dataset.Builder(presentation)
                var hasValue = false

                fieldIds.usernameId?.let { id ->
                    if (entry.username.isNotBlank()) {
                        datasetBuilder.setValue(id, AutofillValue.forText(entry.username))
                        hasValue = true
                    }
                }
                fieldIds.passwordId?.let { id ->
                    if (entry.password.isNotBlank()) {
                        datasetBuilder.setValue(id, AutofillValue.forText(entry.password))
                        hasValue = true
                    }
                }

                if (!hasValue) {
                    return@forEach
                }

                // Add biometric authentication if enabled
                if (requireBiometric) {
                    val authIntent = createAuthPendingIntent(entry, fieldIds)
                    datasetBuilder.setAuthentication(authIntent.intentSender)
                }

                if (
                    inlineConfig != null &&
                    inlineUsed < inlineConfig.capacity &&
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.R
                ) {
                    val inlinePresentation = buildInlinePresentation(
                        entry = entry,
                        spec = inlineConfig.specForIndex(inlineUsed),
                    )
                    if (inlinePresentation != null) {
                        datasetBuilder.setInlinePresentation(inlinePresentation)
                        inlineUsed += 1
                    }
                }

                responseBuilder.addDataset(datasetBuilder.build())
                datasetsAdded += 1
            }

        inlineUsed = addShowAllDataset(responseBuilder, fieldIds, inlineConfig, inlineUsed)

        callback.onSuccess(responseBuilder.build())
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        // Saving new credentials is not handled yet. Consider implementing future improvements.
        callback.onSuccess()
    }

    companion object {
        private const val MAX_RESPONSE_DATASETS = 4
        private const val SHOW_ALL_REQUEST_CODE = 1001
        private const val AUTH_REQUEST_CODE_BASE = 2000
    }

    private fun createAuthPendingIntent(
        entry: AutofillEntry,
        fieldIds: AutofillFieldIds,
    ): PendingIntent {
        val intent = Intent(this, AutofillAuthActivity::class.java).apply {
            putExtra(AutofillAuthActivity.EXTRA_USERNAME_ID, fieldIds.usernameId)
            putExtra(AutofillAuthActivity.EXTRA_PASSWORD_ID, fieldIds.passwordId)
            putExtra(AutofillAuthActivity.EXTRA_ENTRY_ID, entry.id)
            putExtra(AutofillAuthActivity.EXTRA_USERNAME, entry.username)
            putExtra(AutofillAuthActivity.EXTRA_PASSWORD, entry.password)
            putExtra(AutofillAuthActivity.EXTRA_TITLE, entry.title)
        }

        val requestCodeSeed = entry.id ?: (entry.username + entry.title).hashCode()
        val requestCode = (requestCodeSeed and Int.MAX_VALUE) + AUTH_REQUEST_CODE_BASE

        val baseFlags = PendingIntent.FLAG_UPDATE_CURRENT
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            baseFlags or PendingIntent.FLAG_MUTABLE
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            baseFlags or PendingIntent.FLAG_IMMUTABLE
        } else {
            baseFlags
        }

        return PendingIntent.getActivity(this, requestCode, intent, flags)
    }

    private fun createInlineConfig(request: FillRequest): InlineConfig? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return null
        }
        val inlineRequest = request.inlineSuggestionsRequest ?: return null
        val specs = inlineRequest.inlinePresentationSpecs ?: return null
        if (specs.isEmpty()) {
            return null
        }
        val maxSuggestions = inlineRequest.maxSuggestionCount
        if (maxSuggestions <= 0) {
            return null
        }
        return InlineConfig(specs.toList(), maxSuggestions)
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun buildInlinePresentation(
        entry: AutofillEntry,
        spec: InlinePresentationSpec,
    ): InlinePresentation? {
        val title = entry.primaryLabel()
        if (title.isBlank()) {
            return null
        }

        val attributionIntent = createInlineAttributionIntent(entry)
        return AutofillUiFactory.createInlinePresentation(
            context = this,
            entry = entry,
            spec = spec,
            attribution = attributionIntent,
        )
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun createInlineAttributionIntent(entry: AutofillEntry): PendingIntent {
        val launchIntent = packageManager?.getLaunchIntentForPackage(packageName)
            ?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            ?: Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }

        val requestCodeSeed = entry.id ?: (entry.username + entry.title).hashCode()
        val requestCode = requestCodeSeed and Int.MAX_VALUE
        val baseFlags = PendingIntent.FLAG_UPDATE_CURRENT
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            baseFlags or PendingIntent.FLAG_IMMUTABLE
        } else {
            baseFlags
        }
        return PendingIntent.getActivity(this, requestCode, launchIntent, flags)
    }

    private fun addShowAllDataset(
        responseBuilder: FillResponse.Builder,
        fieldIds: AutofillFieldIds,
        inlineConfig: InlineConfig?,
        inlineUsed: Int,
    ): Int {
        val pendingIntent = createShowAllPendingIntent(fieldIds)
        val presentation = AutofillUiFactory.createDatasetPresentation(
            context = this,
            title = getString(R.string.autofill_show_all_label),
            subtitle = getString(R.string.autofill_show_all_subtitle),
        )

        val datasetBuilder = Dataset.Builder()
        var valueBound = false

        fieldIds.usernameId?.let { id ->
            datasetBuilder.setValue(id, null, presentation)
            valueBound = true
        }

        fieldIds.passwordId?.let { id ->
            val passwordPresentation = if (fieldIds.usernameId != null) {
                AutofillUiFactory.createDatasetPresentation(
                    context = this,
                    title = getString(R.string.autofill_show_all_label),
                    subtitle = getString(R.string.autofill_show_all_subtitle),
                )
            } else {
                presentation
            }
            datasetBuilder.setValue(id, null, passwordPresentation)
            valueBound = true
        }

        if (!valueBound) {
            val ids = listOfNotNull(fieldIds.usernameId, fieldIds.passwordId).toTypedArray()
            if (ids.isNotEmpty()) {
                responseBuilder.setAuthentication(ids, pendingIntent.intentSender, null as RemoteViews?)
            }
            return inlineUsed
        }

        datasetBuilder.setAuthentication(pendingIntent.intentSender)

        var inlineCount = inlineUsed
        if (
            inlineConfig != null &&
            inlineCount < inlineConfig.capacity &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.R
        ) {
            val inlinePresentation = AutofillUiFactory.createInlinePresentation(
                context = this,
                title = getString(R.string.autofill_show_all_label),
                subtitle = getString(R.string.autofill_show_all_subtitle),
                spec = inlineConfig.specForIndex(inlineCount),
                attribution = pendingIntent,
            )
            if (inlinePresentation != null) {
                datasetBuilder.setInlinePresentation(inlinePresentation)
                inlineCount += 1
            }
        }

        responseBuilder.addDataset(datasetBuilder.build())
        return inlineCount
    }

    private fun createShowAllPendingIntent(fieldIds: AutofillFieldIds): PendingIntent {
        val intent = Intent(this, AutofillChooserActivity::class.java).apply {
            putExtra(AutofillChooserActivity.EXTRA_USERNAME_ID, fieldIds.usernameId)
            putExtra(AutofillChooserActivity.EXTRA_PASSWORD_ID, fieldIds.passwordId)
            putExtra(AutofillChooserActivity.EXTRA_WEB_DOMAIN, fieldIds.webDomain)
            putExtra(AutofillChooserActivity.EXTRA_PACKAGE_NAME, fieldIds.packageName)
        }

        val baseFlags = PendingIntent.FLAG_UPDATE_CURRENT
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            baseFlags or PendingIntent.FLAG_MUTABLE
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            baseFlags or PendingIntent.FLAG_IMMUTABLE
        } else {
            baseFlags
        }

        val requestCode = (fieldIds.webDomain ?: fieldIds.packageName ?: "").hashCode() xor SHOW_ALL_REQUEST_CODE
        return PendingIntent.getActivity(this, requestCode, intent, flags)
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private data class InlineConfig(
        val specs: List<InlinePresentationSpec>,
        val maxSuggestionCount: Int,
    ) {
        val capacity: Int = maxSuggestionCount.coerceAtMost(specs.size)

        fun specForIndex(index: Int): InlinePresentationSpec {
            return specs.getOrElse(index) { specs.last() }
        }
    }
}
