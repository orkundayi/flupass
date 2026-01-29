package com.flutech.flupass

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import com.flutech.flupass.autofill.AutofillDataStore
import com.flutech.flupass.autofill.AutofillEntry
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
	private val autofillDataStore by lazy { AutofillDataStore(this) }

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		
		// Autofill Channel
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUTOFILL_CHANNEL)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"syncCredentials" -> {
						@Suppress("UNCHECKED_CAST")
						val rawEntries = call.argument<List<Map<String, Any?>>>("entries")
							?: emptyList()
						val entries = rawEntries.mapNotNull(AutofillEntry::fromMap)
						autofillDataStore.saveCredentials(entries)
						result.success(null)
					}

					"openAutofillSettings" -> {
						val opened = openAutofillSettings()
						result.success(opened)
					}

					"setBiometricEnabled" -> {
						val enabled = call.argument<Boolean>("enabled") ?: true
						autofillDataStore.isBiometricEnabled = enabled
						result.success(true)
					}

					"isBiometricEnabled" -> {
						result.success(autofillDataStore.isBiometricEnabled)
					}

					"clearAutofillData" -> {
						autofillDataStore.clearAllData()
						result.success(null)
					}

					else -> result.notImplemented()
				}
			}
		
		// Settings Channel
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SETTINGS_CHANNEL)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"openAppSettings" -> {
						val opened = openAppSettings()
						result.success(opened)
					}
					else -> result.notImplemented()
				}
			}
	}

	private fun openAutofillSettings(): Boolean {
		val intents = mutableListOf<Intent>()
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			intents += Intent(Settings.ACTION_REQUEST_SET_AUTOFILL_SERVICE).apply {
				data = Uri.parse("package:$packageName")
			}
			intents += Intent("android.settings.AUTOFILL_SETTINGS")
		}
		intents += Intent(Settings.ACTION_SETTINGS)

		for (intent in intents) {
			try {
				startActivity(intent)
				return true
			} catch (error: ActivityNotFoundException) {
				continue
			} catch (error: Exception) {
				continue
			}
		}
		return false
	}

	private fun openAppSettings(): Boolean {
		return try {
			val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
				data = Uri.parse("package:$packageName")
			}
			startActivity(intent)
			true
		} catch (error: ActivityNotFoundException) {
			// Fallback: genel ayarları aç
			try {
				startActivity(Intent(Settings.ACTION_SETTINGS))
				true
			} catch (_: Exception) {
				false
			}
		} catch (_: Exception) {
			false
		}
	}

	companion object {
		private const val AUTOFILL_CHANNEL = "com.flutech.flupass/autofill"
		private const val SETTINGS_CHANNEL = "com.flutech.flupass/settings"
	}
}
