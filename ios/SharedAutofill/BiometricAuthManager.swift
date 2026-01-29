import LocalAuthentication
import Foundation

/// Biometrik doğrulama yöneticisi
final class BiometricAuthManager {
    
    enum BiometricType {
        case none
        case touchID
        case faceID
        case opticID // Vision Pro
    }
    
    enum AuthResult {
        case success
        case failed(Error?)
        case notAvailable
        case notEnrolled
        case cancelled
    }
    
    private let context = LAContext()
    
    /// Mevcut biometrik tipi
    var biometricType: BiometricType {
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        switch context.biometryType {
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        case .opticID:
            return .opticID
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }
    
    /// Biometrik doğrulama mevcut mu?
    var isBiometricAvailable: Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    /// Cihaz şifresi ile doğrulama mevcut mu?
    var isPasscodeAvailable: Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }
    
    /// Biometrik veya şifre ile doğrulama yap
    /// - Parameters:
    ///   - reason: Kullanıcıya gösterilecek neden
    ///   - completion: Sonuç callback'i
    func authenticate(reason: String, completion: @escaping (AuthResult) -> Void) {
        let context = LAContext()
        context.localizedCancelTitle = "İptal"
        context.localizedFallbackTitle = "Şifre Kullan"
        
        var error: NSError?
        
        // Önce biometrik dene, yoksa device passcode
        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication
        
        guard context.canEvaluatePolicy(policy, error: &error) else {
            if let error = error {
                switch error.code {
                case LAError.biometryNotEnrolled.rawValue:
                    completion(.notEnrolled)
                case LAError.biometryNotAvailable.rawValue:
                    completion(.notAvailable)
                default:
                    completion(.failed(error))
                }
            } else {
                completion(.notAvailable)
            }
            return
        }
        
        context.evaluatePolicy(policy, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success)
                } else if let error = error as? LAError {
                    switch error.code {
                    case .userCancel, .appCancel, .systemCancel:
                        completion(.cancelled)
                    case .userFallback:
                        // Kullanıcı şifre kullanmak istedi, tekrar dene
                        self.authenticateWithPasscode(reason: reason, completion: completion)
                    default:
                        completion(.failed(error))
                    }
                } else {
                    completion(.failed(error))
                }
            }
        }
    }
    
    /// Sadece cihaz şifresi ile doğrulama
    private func authenticateWithPasscode(reason: String, completion: @escaping (AuthResult) -> Void) {
        let context = LAContext()
        context.localizedCancelTitle = "İptal"
        
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            completion(.notAvailable)
            return
        }
        
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success)
                } else if let error = error as? LAError, error.code == .userCancel {
                    completion(.cancelled)
                } else {
                    completion(.failed(error))
                }
            }
        }
    }
    
    /// Biometrik tip için lokalize edilmiş isim
    var localizedBiometricName: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "Şifre"
        }
    }
}
