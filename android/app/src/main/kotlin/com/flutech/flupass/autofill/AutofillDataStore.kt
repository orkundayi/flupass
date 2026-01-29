package com.flutech.flupass.autofill

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import org.json.JSONArray

class AutofillDataStore(context: Context) {
    private val preferences: SharedPreferences = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        EncryptedSharedPreferences.create(
            context,
            PREFERENCES_FILE,
            MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build(),
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    } else {
        context.getSharedPreferences(PREFERENCES_FILE, Context.MODE_PRIVATE)
    }

    // ========== Credentials ==========

    fun saveCredentials(entries: List<AutofillEntry>) {
        if (entries.isEmpty()) {
            clearCredentials()
            return
        }
        val array = JSONArray()
        entries.take(MAX_DATASET_SIZE).forEach { entry ->
            array.put(entry.toJson())
        }
        preferences.edit()
            .putString(KEY_CREDENTIALS, array.toString())
            .apply()
    }

    fun loadCredentials(): List<AutofillEntry> {
        val raw = preferences.getString(KEY_CREDENTIALS, null) ?: return emptyList()
        return AutofillEntry.fromJsonArray(raw)
    }

    fun clearCredentials() {
        preferences.edit().remove(KEY_CREDENTIALS).apply()
    }

    // ========== Settings ==========

    var isBiometricEnabled: Boolean
        get() = preferences.getBoolean(KEY_BIOMETRIC_ENABLED, true)
        set(value) {
            preferences.edit().putBoolean(KEY_BIOMETRIC_ENABLED, value).apply()
        }

    // ========== Clear All ==========

    fun clearAllData() {
        preferences.edit()
            .remove(KEY_CREDENTIALS)
            .apply()
    }

    companion object {
        private const val PREFERENCES_FILE = "flupass_autofill_store"
        private const val KEY_CREDENTIALS = "credentials"
        private const val KEY_BIOMETRIC_ENABLED = "biometric_enabled"
        private const val MAX_DATASET_SIZE = 500
    }
}
