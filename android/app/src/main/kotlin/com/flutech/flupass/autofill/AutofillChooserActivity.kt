package com.flutech.flupass.autofill

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.autofill.AutofillId
import android.view.autofill.AutofillValue
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.fragment.app.FragmentActivity
import androidx.core.widget.doAfterTextChanged
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.flutech.flupass.R
import com.google.android.material.button.MaterialButton
import com.google.android.material.textfield.TextInputEditText

class AutofillChooserActivity : AppCompatActivity() {

    private lateinit var recyclerView: RecyclerView
    private lateinit var emptyView: TextView
    private lateinit var headerTitle: TextView
    private lateinit var headerSubtitle: TextView
    private lateinit var searchInput: TextInputEditText
    private lateinit var toggleButton: MaterialButton
    private lateinit var adapter: AutofillChooserAdapter
    private lateinit var biometricHelper: BiometricHelper

    private val dataStore by lazy { AutofillDataStore(this) }

    private var allEntries: List<AutofillEntry> = emptyList()
    private var isShowingAllCredentials = false
    private var searchQuery: String = ""
    private var usernameId: AutofillId? = null
    private var passwordId: AutofillId? = null
    private var webDomain: String? = null
    private var formattedDomain: String? = null
    private var isAuthenticated = false
    private var pendingEntry: AutofillEntry? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_autofill_chooser)
        setResult(Activity.RESULT_CANCELED)

        biometricHelper = BiometricHelper(this)

        headerTitle = findViewById(R.id.autofill_header_title)
        headerSubtitle = findViewById(R.id.autofill_header_subtitle)
        recyclerView = findViewById(R.id.autofill_list)
        emptyView = findViewById(R.id.autofill_empty_view)
        searchInput = findViewById(R.id.autofill_search_input)
        toggleButton = findViewById(R.id.autofill_toggle_button)

        adapter = AutofillChooserAdapter { entry ->
            onEntrySelected(entry)
        }

        recyclerView.layoutManager = LinearLayoutManager(this)
        recyclerView.adapter = adapter

        searchInput.doAfterTextChanged { text ->
            searchQuery = text?.toString().orEmpty()
            applyFilters()
        }

        toggleButton.setOnClickListener {
            if (formattedDomain.isNullOrBlank()) return@setOnClickListener
            isShowingAllCredentials = !isShowingAllCredentials
            applyFilters()
        }

        usernameId = intent.parcelableExtra(EXTRA_USERNAME_ID)
        passwordId = intent.parcelableExtra(EXTRA_PASSWORD_ID)
        webDomain = intent.getStringExtra(EXTRA_WEB_DOMAIN)
        formattedDomain = webDomain?.let { formatDomain(it) }?.takeIf { it.isNotBlank() }

        headerTitle.text = formattedDomain ?: getString(R.string.autofill_chooser_title)
        headerSubtitle.text = formattedDomain?.let {
            getString(R.string.autofill_chooser_message_domain, it)
        } ?: getString(R.string.autofill_chooser_message)

        loadEntries()
    }

    private fun onEntrySelected(entry: AutofillEntry) {
        val shouldAuthenticate = dataStore.isBiometricEnabled &&
            biometricHelper.isBiometricAvailable()

        if (shouldAuthenticate && !isAuthenticated) {
            pendingEntry = entry
            showBiometricPrompt()
        } else {
            returnAutofillResult(entry)
        }
    }

    private fun showBiometricPrompt() {
        biometricHelper.authenticate(
            title = getString(R.string.biometric_prompt_title),
            subtitle = getString(R.string.biometric_prompt_subtitle),
            negativeButtonText = getString(R.string.biometric_prompt_cancel),
            onSuccess = {
                isAuthenticated = true
                pendingEntry?.let { entry ->
                    returnAutofillResult(entry)
                }
                pendingEntry = null
            },
            onError = { _, errorMessage ->
                pendingEntry = null
                // Show error but don't close activity
                android.widget.Toast.makeText(
                    this,
                    errorMessage,
                    android.widget.Toast.LENGTH_SHORT,
                ).show()
            },
            onCancel = {
                pendingEntry = null
                // User cancelled, just stay on chooser screen
            },
        )
    }

    private fun returnAutofillResult(entry: AutofillEntry) {
        val dataset = buildDataset(entry)
        if (dataset != null) {
            val reply = Intent().apply {
                putExtra(android.view.autofill.AutofillManager.EXTRA_AUTHENTICATION_RESULT, dataset)
            }
            setResult(Activity.RESULT_OK, reply)
            finish()
        }
    }

    private fun loadEntries() {
    allEntries = dataStore.loadCredentials()
    isShowingAllCredentials = false
    searchQuery = ""
    searchInput.setText("")
    applyFilters()
    }

    private fun applyFilters() {
        val hasDomain = !formattedDomain.isNullOrBlank()
        val domainMatches = if (hasDomain) {
            filterEntriesByDomain(allEntries, webDomain)
        } else {
            emptyList()
        }

        if (!isShowingAllCredentials && hasDomain && domainMatches.isEmpty()) {
            isShowingAllCredentials = true
        }

        var filtered = when {
            !isShowingAllCredentials && hasDomain && domainMatches.isNotEmpty() -> domainMatches
            else -> allEntries
        }

        if (searchQuery.isNotBlank()) {
            val query = searchQuery.lowercase()
            filtered = filtered.filter { entry ->
                entry.primaryLabel().contains(query, ignoreCase = true) ||
                    (entry.secondaryLabel()?.contains(query, ignoreCase = true) ?: false) ||
                    entry.username.contains(query, ignoreCase = true) ||
                    entry.title.contains(query, ignoreCase = true) ||
                    (entry.website?.contains(query, ignoreCase = true) ?: false)
            }
        }

        adapter.submitList(filtered)
        updateEmptyState(filtered.isEmpty())
        updateToggleButton()
    }

    private fun updateToggleButton() {
        val hasDomain = !formattedDomain.isNullOrBlank()
        val shouldShowToggle = hasDomain && allEntries.isNotEmpty()
        if (shouldShowToggle) {
            val labelRes = if (isShowingAllCredentials) {
                R.string.autofill_show_domain_label
            } else {
                R.string.autofill_show_all_label
            }
            toggleButton.setText(labelRes)
            toggleButton.isEnabled = allEntries.isNotEmpty()
        }
        toggleButton.visibility = if (shouldShowToggle) View.VISIBLE else View.GONE
    }

    private fun updateEmptyState(isEmpty: Boolean) {
        emptyView.visibility = if (isEmpty) View.VISIBLE else View.GONE
        recyclerView.visibility = if (isEmpty) View.GONE else View.VISIBLE
        if (!isEmpty) return

        emptyView.text = when {
            searchQuery.isNotBlank() -> getString(R.string.autofill_empty_search)
            isShowingAllCredentials || formattedDomain.isNullOrBlank() -> getString(R.string.autofill_chooser_empty)
            else -> getString(R.string.autofill_chooser_empty_domain, formattedDomain)
        }
    }

    private fun buildDataset(entry: AutofillEntry): android.service.autofill.Dataset? {
        if (usernameId == null && passwordId == null) return null
        val presentation = AutofillUiFactory.createDatasetPresentation(this, entry)
        val builder = android.service.autofill.Dataset.Builder(presentation)
        var hasValue = false

        usernameId?.let { id ->
            if (entry.username.isNotBlank()) {
                builder.setValue(id, AutofillValue.forText(entry.username))
                hasValue = true
            }
        }
        passwordId?.let { id ->
            if (entry.password.isNotBlank()) {
                builder.setValue(id, AutofillValue.forText(entry.password))
                hasValue = true
            }
        }

        return if (hasValue) builder.build() else null
    }

    private fun formatDomain(raw: String): String {
        return raw
            .removePrefix("https://")
            .removePrefix("http://")
            .removePrefix("www.")
            .trimEnd('/')
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
        const val EXTRA_WEB_DOMAIN = "com.flutech.flupass.extra.WEB_DOMAIN"
        const val EXTRA_PACKAGE_NAME = "com.flutech.flupass.extra.PACKAGE_NAME"
    }
}
