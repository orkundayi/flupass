import AuthenticationServices
import Foundation

final class AutofillCredentialStore {
    private let appGroupIdentifier = "group.com.flutech.flupass"
    private let credentialsKey = "autofill.credentials"
    private let creditCardsKey = "autofill.creditCards"
    private let biometricEnabledKey = "autofill.biometricEnabled"
    private let lastSyncKey = "autofill.lastSync"
    private let lastIdentityHashKey = "autofill.lastIdentityHash"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
    
    // MARK: - Settings
    
    /// Biometrik doğrulama aktif mi?
    var isBiometricEnabled: Bool {
        get {
            // Not: bool(forKey:) key yoksa false döner, nil değil!
            // Bu yüzden object(forKey:) ile kontrol ediyoruz
            guard let defaults = userDefaults else { return true }
            if defaults.object(forKey: biometricEnabledKey) == nil {
                return true // Varsayılan olarak açık
            }
            return defaults.bool(forKey: biometricEnabledKey)
        }
        set {
            userDefaults?.set(newValue, forKey: biometricEnabledKey)
            userDefaults?.synchronize()
        }
    }
    
    /// Son senkronizasyon zamanı
    var lastSyncDate: Date? {
        get {
            userDefaults?.object(forKey: lastSyncKey) as? Date
        }
        set {
            userDefaults?.set(newValue, forKey: lastSyncKey)
            userDefaults?.synchronize()
        }
    }
    
    /// Son senkronize edilen identity'lerin hash'i (değişiklik tespiti için)
    private var lastIdentityHash: String? {
        get {
            userDefaults?.string(forKey: lastIdentityHashKey)
        }
        set {
            userDefaults?.set(newValue, forKey: lastIdentityHashKey)
        }
    }

    // MARK: - Credentials

    func saveCredentials(_ credentials: [AutofillCredential]) {
        guard let defaults = userDefaults else {
            NSLog("[AutofillCredentialStore] UserDefaults not available for app group")
            return
        }
        do {
            let data = try encoder.encode(credentials)
            defaults.set(data, forKey: credentialsKey)
            lastSyncDate = Date()
            defaults.synchronize()
            updateCredentialIdentities(credentials)
            NSLog("[AutofillCredentialStore] Successfully saved \(credentials.count) credentials")
        } catch {
            NSLog("[AutofillCredentialStore] Failed to save credentials: \(error.localizedDescription)")
        }
    }

    func loadCredentials() -> [AutofillCredential] {
        guard let defaults = userDefaults, let data = defaults.data(forKey: credentialsKey) else {
            NSLog("[AutofillCredentialStore] No credentials data found")
            return []
        }
        do {
            let credentials = try decoder.decode([AutofillCredential].self, from: data)
            NSLog("[AutofillCredentialStore] Loaded \(credentials.count) credentials")
            return credentials
        } catch {
            NSLog("[AutofillCredentialStore] Failed to decode credentials: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Credit Cards

    func saveCreditCards(_ cards: [AutofillCreditCard]) {
        guard let defaults = userDefaults else {
            NSLog("[AutofillCredentialStore] UserDefaults not available for app group")
            return
        }
        do {
            let data = try encoder.encode(cards)
            defaults.set(data, forKey: creditCardsKey)
            defaults.synchronize()
            NSLog("[AutofillCredentialStore] Successfully saved \(cards.count) credit cards")
        } catch {
            NSLog("[AutofillCredentialStore] Failed to save credit cards: \(error.localizedDescription)")
        }
    }

    func loadCreditCards() -> [AutofillCreditCard] {
        guard let defaults = userDefaults, let data = defaults.data(forKey: creditCardsKey) else {
            NSLog("[AutofillCredentialStore] No credit cards data found")
            return []
        }
        do {
            let cards = try decoder.decode([AutofillCreditCard].self, from: data)
            NSLog("[AutofillCredentialStore] Loaded \(cards.count) credit cards")
            return cards
        } catch {
            NSLog("[AutofillCredentialStore] Failed to decode credit cards: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Credential Identities

    private func updateCredentialIdentities(_ credentials: [AutofillCredential]) {
        let validCredentials = credentials.filter { !$0.username.isEmpty && !$0.password.isEmpty }
        let identities = validCredentials.map { $0.makeIdentity() }
        
        // Değişiklik var mı kontrol et (gereksiz senkronizasyonları önle)
        let currentHash = computeIdentityHash(validCredentials)
        if currentHash == lastIdentityHash {
            NSLog("[AutofillCredentialStore] No changes detected, skipping identity update")
            return
        }

        DispatchQueue.main.async {
            ASCredentialIdentityStore.shared.getState { [weak self] state in
                guard let self = self else { return }
                
                guard state.isEnabled else {
                    NSLog("[AutofillCredentialStore] Identity store disabled by user")
                    return
                }
                
                if state.supportsIncrementalUpdates {
                    // Incremental güncelleme destekleniyorsa akıllı güncelleme yap
                    self.performIncrementalUpdate(
                        newCredentials: validCredentials,
                        newIdentities: identities,
                        currentHash: currentHash
                    )
                } else {
                    // Desteklenmiyorsa tam değiştirme yap
                    self.replaceAllIdentities(identities, hash: currentHash)
                }
            }
        }
    }
    
    /// Incremental güncelleme - sadece değişenleri güncelle
    private func performIncrementalUpdate(
        newCredentials: [AutofillCredential],
        newIdentities: [ASPasswordCredentialIdentity],
        currentHash: String
    ) {
        // Önceki credential'ları yükle
        let previousCredentials = loadPreviousCredentialSnapshot()
        
        // Değişiklikleri hesapla
        let previousIds = Set(previousCredentials.map { $0.id })
        let currentIds = Set(newCredentials.map { $0.id })
        
        // Silinen credential'lar
        let deletedIds = previousIds.subtracting(currentIds)
        
        // Yeni eklenen credential'lar
        let addedIds = currentIds.subtracting(previousIds)
        
        // Güncellenen credential'lar (aynı ID ama farklı içerik)
        let potentiallyUpdatedIds = previousIds.intersection(currentIds)
        var updatedCredentials: [AutofillCredential] = []
        
        for id in potentiallyUpdatedIds {
            guard let oldCred = previousCredentials.first(where: { $0.id == id }),
                  let newCred = newCredentials.first(where: { $0.id == id }) else {
                continue
            }
            
            // İçerik değişmiş mi?
            if oldCred.username != newCred.username ||
               oldCred.website != newCred.website {
                updatedCredentials.append(newCred)
            }
        }
        
        // Eğer çok fazla değişiklik varsa, toplu değiştirme daha verimli
        let totalChanges = deletedIds.count + addedIds.count + updatedCredentials.count
        if totalChanges > newCredentials.count / 2 {
            NSLog("[AutofillCredentialStore] Too many changes (\(totalChanges)), using full replace")
            replaceAllIdentities(newIdentities, hash: currentHash)
            return
        }
        
        // Incremental güncelleme yap
        let group = DispatchGroup()
        var hasError = false
        
        // 1. Silinenleri kaldır
        if !deletedIds.isEmpty {
            let deletedIdentities = previousCredentials
                .filter { deletedIds.contains($0.id) }
                .map { $0.makeIdentity() }
            
            group.enter()
            ASCredentialIdentityStore.shared.removeCredentialIdentities(deletedIdentities) { success, error in
                if let error = error {
                    NSLog("[AutofillCredentialStore] Failed to remove identities: \(error.localizedDescription)")
                    hasError = true
                } else {
                    NSLog("[AutofillCredentialStore] Removed \(deletedIdentities.count) identities")
                }
                group.leave()
            }
        }
        
        // 2. Güncellenenleri kaldır (sonra yeniden eklenecek)
        if !updatedCredentials.isEmpty {
            let updatedIdentities = updatedCredentials.map { $0.makeIdentity() }
            
            group.enter()
            ASCredentialIdentityStore.shared.removeCredentialIdentities(updatedIdentities) { success, error in
                if let error = error {
                    NSLog("[AutofillCredentialStore] Failed to remove updated identities: \(error.localizedDescription)")
                }
                group.leave()
            }
        }
        
        // 3. Yeni ve güncellenen identity'leri ekle
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            if hasError {
                // Hata olduysa tam değiştirme yap
                self.replaceAllIdentities(newIdentities, hash: currentHash)
                return
            }
            
            let addedCredentials = newCredentials.filter { addedIds.contains($0.id) }
            let toAdd = (addedCredentials + updatedCredentials).map { $0.makeIdentity() }
            
            if toAdd.isEmpty {
                self.lastIdentityHash = currentHash
                self.savePreviousCredentialSnapshot(newCredentials)
                NSLog("[AutofillCredentialStore] Incremental update complete (no additions)")
                return
            }
            
            ASCredentialIdentityStore.shared.saveCredentialIdentities(toAdd) { success, error in
                if let error = error {
                    NSLog("[AutofillCredentialStore] Failed to add identities: \(error.localizedDescription)")
                } else {
                    NSLog("[AutofillCredentialStore] Added \(toAdd.count) identities (incremental)")
                    self.lastIdentityHash = currentHash
                    self.savePreviousCredentialSnapshot(newCredentials)
                }
            }
        }
    }
    
    private func replaceAllIdentities(_ identities: [ASPasswordCredentialIdentity], hash: String) {
        ASCredentialIdentityStore.shared.replaceCredentialIdentities(with: identities) { [weak self] success, error in
            if let error = error {
                NSLog("[AutofillCredentialStore] Failed to update identities: \(error.localizedDescription)")
            } else if !success {
                NSLog("[AutofillCredentialStore] Updating identities not permitted by system")
            } else {
                NSLog("[AutofillCredentialStore] Successfully replaced \(identities.count) password identities in QuickType bar")
                self?.lastIdentityHash = hash
            }
        }
    }
    
    // MARK: - Credential Snapshot (for incremental updates)
    
    private let previousCredentialsKey = "autofill.previousCredentials"
    
    private func loadPreviousCredentialSnapshot() -> [AutofillCredential] {
        guard let defaults = userDefaults,
              let data = defaults.data(forKey: previousCredentialsKey) else {
            return []
        }
        return (try? decoder.decode([AutofillCredential].self, from: data)) ?? []
    }
    
    private func savePreviousCredentialSnapshot(_ credentials: [AutofillCredential]) {
        guard let defaults = userDefaults,
              let data = try? encoder.encode(credentials) else {
            return
        }
        defaults.set(data, forKey: previousCredentialsKey)
    }
    
    /// Credential listesinin hash'ini hesapla
    private func computeIdentityHash(_ credentials: [AutofillCredential]) -> String {
        let sortedCredentials = credentials.sorted { $0.id < $1.id }
        let hashInput = sortedCredentials.map { "\($0.id):\($0.username):\($0.website ?? "")" }.joined(separator: "|")
        
        // Basit hash - gerçek uygulamada SHA256 kullanılabilir
        var hash = 0
        for char in hashInput.unicodeScalars {
            hash = 31 &* hash &+ Int(char.value)
        }
        return String(hash)
    }
    
    // MARK: - Cleanup
    
    /// Tüm verileri temizle
    func clearAllData() {
        guard let defaults = userDefaults else { return }
        defaults.removeObject(forKey: credentialsKey)
        defaults.removeObject(forKey: creditCardsKey)
        defaults.removeObject(forKey: lastSyncKey)
        defaults.synchronize()
        
        ASCredentialIdentityStore.shared.removeAllCredentialIdentities { success, error in
            if let error {
                NSLog("[AutofillCredentialStore] Failed to clear identities: \(error.localizedDescription)")
            } else {
                NSLog("[AutofillCredentialStore] All data cleared")
            }
        }
    }
}
