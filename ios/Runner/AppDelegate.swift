import AuthenticationServices
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let autofillChannelName = "com.flutech.flupass/autofill"
  private let settingsChannelName = "com.flutech.flupass/settings"
  private let autofillStore = AutofillCredentialStore()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    configureAutofillChannel()
    configureSettingsChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureAutofillChannel() {
    guard
      let controller = window?.rootViewController as? FlutterViewController
    else {
      return
    }

    let channel = FlutterMethodChannel(
      name: autofillChannelName,
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "syncCredentials":
        self?.handleSyncCredentials(call: call, result: result)
      case "syncCreditCards":
        self?.handleSyncCreditCards(call: call, result: result)
      case "openAutofillSettings":
        self?.handleOpenSettings(result: result)
      case "openPasswordSettings":
        self?.handleOpenPasswordSettings(result: result)
      case "setBiometricEnabled":
        self?.handleSetBiometricEnabled(call: call, result: result)
      case "isBiometricEnabled":
        self?.handleIsBiometricEnabled(result: result)
      case "clearAutofillData":
        self?.handleClearAutofillData(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func configureSettingsChannel() {
    guard
      let controller = window?.rootViewController as? FlutterViewController
    else {
      return
    }

    let channel = FlutterMethodChannel(
      name: settingsChannelName,
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "openAppSettings":
        self?.handleOpenAppSettings(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func handleOpenAppSettings(result: @escaping FlutterResult) {
    // Doğrudan FluPass uygulama ayarlarını aç
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      result(false)
      return
    }

    DispatchQueue.main.async {
      if UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url, options: [:]) { opened in
          result(opened)
        }
      } else {
        result(false)
      }
    }
  }

  private func handleSyncCredentials(
    call: FlutterMethodCall,
    result: FlutterResult
  ) {
    guard
      let arguments = call.arguments as? [String: Any],
      let rawEntries = arguments["entries"] as? [[String: Any]]
    else {
      result(FlutterError(
        code: "invalid_arguments",
        message: "entries payload eksik",
        details: nil
      ))
      return
    }

    let credentials = rawEntries.compactMap { entry -> AutofillCredential? in
      guard
        let idValue = entry["id"],
        let id = (idValue as? Int) ?? (idValue as? NSNumber)?.intValue,
        id > 0,
        let title = entry["title"] as? String,
        let username = entry["username"] as? String,
        let password = entry["password"] as? String
      else {
        return nil
      }

      let website = entry["website"] as? String
      return AutofillCredential(
        id: id,
        title: title,
        username: username,
        password: password,
        website: website?.isEmpty == true ? nil : website
      )
    }

    autofillStore.saveCredentials(credentials)
    result(nil)
  }

  private func handleSyncCreditCards(
    call: FlutterMethodCall,
    result: FlutterResult
  ) {
    guard
      let arguments = call.arguments as? [String: Any],
      let rawEntries = arguments["entries"] as? [[String: Any]]
    else {
      result(FlutterError(
        code: "invalid_arguments",
        message: "entries payload eksik",
        details: nil
      ))
      return
    }

    let cards = rawEntries.compactMap { entry -> AutofillCreditCard? in
      guard
        let idValue = entry["id"],
        let id = (idValue as? Int) ?? (idValue as? NSNumber)?.intValue,
        id > 0,
        let cardHolderName = entry["cardHolderName"] as? String,
        let cardNumber = entry["cardNumber"] as? String,
        let expiryDate = entry["expiryDate"] as? String,
        let cvv = entry["cvv"] as? String
      else {
        return nil
      }

      let displayName = entry["displayName"] as? String
      return AutofillCreditCard(
        id: id,
        cardHolderName: cardHolderName,
        cardNumber: cardNumber,
        expiryDate: expiryDate,
        cvv: cvv,
        displayName: displayName?.isEmpty == true ? nil : displayName
      )
    }

    autofillStore.saveCreditCards(cards)
    result(nil)
  }

  private func handleOpenSettings(result: @escaping FlutterResult) {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      result(false)
      return
    }

    DispatchQueue.main.async {
      if UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url, options: [:]) { opened in
          result(opened)
        }
      } else {
        result(false)
      }
    }
  }
  
  private func handleOpenPasswordSettings(result: @escaping FlutterResult) {
    // iOS 16+ için doğrudan parola ayarlarını açma
    // "App-prefs:PASSWORDS" şeması iOS tarafından engellenebilir
    // Alternatif olarak ASSettingsHelper kullanılabilir
    
    DispatchQueue.main.async {
      // iOS 17+ için ASSettingsHelper
      if #available(iOS 17.0, *) {
        ASSettingsHelper.openCredentialProviderAppSettings { error in
          if let error = error {
            print("Password settings error: \(error.localizedDescription)")
            // Fallback to general settings
            self.openGeneralSettings(result: result)
          } else {
            result(true)
          }
        }
        return
      }
      
      // iOS 16 ve altı için genel ayarlara yönlendir
      self.openGeneralSettings(result: result)
    }
  }
  
  private func openGeneralSettings(result: @escaping FlutterResult) {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      result(false)
      return
    }
    
    if UIApplication.shared.canOpenURL(url) {
      UIApplication.shared.open(url, options: [:]) { opened in
        result(opened)
      }
    } else {
      result(false)
    }
  }
  
  private func handleSetBiometricEnabled(
    call: FlutterMethodCall,
    result: FlutterResult
  ) {
    guard
      let arguments = call.arguments as? [String: Any],
      let enabled = arguments["enabled"] as? Bool
    else {
      result(FlutterError(
        code: "invalid_arguments",
        message: "enabled parametresi eksik",
        details: nil
      ))
      return
    }
    
    autofillStore.isBiometricEnabled = enabled
    result(true)
  }
  
  private func handleIsBiometricEnabled(result: FlutterResult) {
    result(autofillStore.isBiometricEnabled)
  }
  
  private func handleClearAutofillData(result: FlutterResult) {
    autofillStore.clearAllData()
    result(nil)
  }
}
