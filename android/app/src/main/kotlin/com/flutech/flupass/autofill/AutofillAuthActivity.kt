package com.flutech.flupass.autofill

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.service.autofill.Dataset
import android.view.autofill.AutofillId
import android.view.autofill.AutofillValue
import androidx.appcompat.app.AppCompatActivity
import com.flutech.flupass.R

/**
 * Activity for biometric authentication before autofill
 * This is shown when user selects an inline credential suggestion
 */
class AutofillAuthActivity : AppCompatActivity() {

    private lateinit var biometricHelper: BiometricHelper
    private val dataStore by lazy { AutofillDataStore(this) }

    private var usernameId: AutofillId? = null
    private var passwordId: AutofillId? = null
    private var entryId: String? = null
    private var username: String? = null
    private var password: String? = null
    private var title: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(Activity.RESULT_CANCELED)

        biometricHelper = BiometricHelper(this)

        // Get data from intent
        usernameId = intent.parcelableExtra(EXTRA_USERNAME_ID)
        passwordId = intent.parcelableExtra(EXTRA_PASSWORD_ID)
        entryId = intent.getStringExtra(EXTRA_ENTRY_ID)
        username = intent.getStringExtra(EXTRA_USERNAME)
        password = intent.getStringExtra(EXTRA_PASSWORD)
        title = intent.getStringExtra(EXTRA_TITLE)

        val shouldAuthenticate = dataStore.isBiometricEnabled &&
            biometricHelper.isBiometricAvailable()

        if (shouldAuthenticate) {
            showBiometricPrompt()
        } else {
            // No biometric needed, just return the data
            returnAutofillResult()
        }
    }

    private fun showBiometricPrompt() {
        biometricHelper.authenticate(
            title = getString(R.string.biometric_prompt_title),
            subtitle = title ?: getString(R.string.biometric_prompt_subtitle),
            negativeButtonText = getString(R.string.biometric_prompt_cancel),
            onSuccess = {
                returnAutofillResult()
            },
            onError = { _, _ ->
                setResult(Activity.RESULT_CANCELED)
                finish()
            },
            onCancel = {
                setResult(Activity.RESULT_CANCELED)
                finish()
            },
        )
    }

    private fun returnAutofillResult() {
        val dataset = buildDataset()
        if (dataset != null) {
            val reply = Intent().apply {
                putExtra(android.view.autofill.AutofillManager.EXTRA_AUTHENTICATION_RESULT, dataset)
            }
            setResult(Activity.RESULT_OK, reply)
        }
        finish()
    }

    private fun buildDataset(): Dataset? {
        if (usernameId == null && passwordId == null) return null
        if (username.isNullOrBlank() && password.isNullOrBlank()) return null

        val presentation = AutofillUiFactory.createDatasetPresentation(
            context = this,
            title = title ?: username ?: "",
            subtitle = if (title != null) username else null,
        )

        val builder = Dataset.Builder(presentation)
        var hasValue = false

        usernameId?.let { id ->
            if (!username.isNullOrBlank()) {
                builder.setValue(id, AutofillValue.forText(username))
                hasValue = true
            }
        }
        passwordId?.let { id ->
            if (!password.isNullOrBlank()) {
                builder.setValue(id, AutofillValue.forText(password))
                hasValue = true
            }
        }

        return if (hasValue) builder.build() else null
    }

    private inline fun <reified T> Intent.parcelableExtra(key: String): T? {
        return when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> getParcelableExtra(key, T::class.java)
            else -> @Suppress("DEPRECATION") getParcelableExtra(key) as? T
        }
    }

    companion object {
        const val EXTRA_USERNAME_ID = "com.flutech.flupass.extra.USERNAME_ID"
        const val EXTRA_PASSWORD_ID = "com.flutech.flupass.extra.PASSWORD_ID"
        const val EXTRA_ENTRY_ID = "com.flutech.flupass.extra.ENTRY_ID"
        const val EXTRA_USERNAME = "com.flutech.flupass.extra.USERNAME"
        const val EXTRA_PASSWORD = "com.flutech.flupass.extra.PASSWORD"
        const val EXTRA_TITLE = "com.flutech.flupass.extra.TITLE"
    }
}
