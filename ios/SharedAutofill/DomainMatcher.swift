import Foundation

/// Domain eşleştirme için yardımcı sınıf
/// Public Suffix List mantığı ile daha doğru eşleştirme yapar
final class DomainMatcher {
    
    /// Yaygın public suffix'ler (TLD'ler ve ikincil domain'ler)
    private static let publicSuffixes: Set<String> = [
        // Generic TLDs
        "com", "net", "org", "edu", "gov", "mil", "int",
        // Country TLDs
        "tr", "uk", "de", "fr", "it", "es", "nl", "be", "at", "ch",
        "pl", "ru", "jp", "cn", "kr", "au", "nz", "ca", "mx", "br",
        // Secondary domains (country-specific)
        "co.uk", "org.uk", "me.uk", "ac.uk", "gov.uk",
        "com.tr", "org.tr", "net.tr", "edu.tr", "gov.tr",
        "com.au", "net.au", "org.au", "edu.au", "gov.au",
        "co.jp", "or.jp", "ne.jp", "ac.jp", "go.jp",
        "com.br", "org.br", "net.br", "edu.br", "gov.br",
        // New TLDs
        "io", "co", "app", "dev", "ai", "me", "tv", "cc", "info", "biz"
    ]
    
    /// URL'den normalize edilmiş domain çıkarır
    /// - Parameter urlString: URL veya domain string'i
    /// - Returns: Normalize edilmiş domain (örn: "instagram.com")
    static func extractDomain(from urlString: String?) -> String? {
        guard let urlString = urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !urlString.isEmpty else {
            return nil
        }
        
        // URL oluşturmayı dene
        let normalizedString: String
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            normalizedString = urlString
        } else {
            normalizedString = "https://\(urlString)"
        }
        
        guard let url = URL(string: normalizedString),
              let host = url.host?.lowercased() else {
            // URL parse edilemezse direkt string'i kullan
            return normalizeHost(urlString.lowercased())
        }
        
        return normalizeHost(host)
    }
    
    /// Host'u normalize eder (www. prefix'ini kaldırır)
    private static func normalizeHost(_ host: String) -> String {
        var normalized = host
        
        // www. prefix'ini kaldır
        if normalized.hasPrefix("www.") {
            normalized = String(normalized.dropFirst(4))
        }
        
        // Trailing slash ve path'leri kaldır
        if let slashIndex = normalized.firstIndex(of: "/") {
            normalized = String(normalized[..<slashIndex])
        }
        
        // Port numarasını kaldır
        if let colonIndex = normalized.firstIndex(of: ":") {
            normalized = String(normalized[..<colonIndex])
        }
        
        return normalized
    }
    
    /// Registrable domain'i çıkarır (örn: "mail.google.com" -> "google.com")
    /// - Parameter domain: Tam domain
    /// - Returns: Registrable domain
    static func extractRegistrableDomain(from domain: String) -> String {
        let parts = domain.lowercased().split(separator: ".").map(String.init)
        
        guard parts.count >= 2 else {
            return domain.lowercased()
        }
        
        // İki parçalı suffix kontrolü (örn: co.uk, com.tr)
        if parts.count >= 3 {
            let twoPartSuffix = "\(parts[parts.count - 2]).\(parts[parts.count - 1])"
            if publicSuffixes.contains(twoPartSuffix) {
                // domain.co.uk gibi -> domain.co.uk döndür
                if parts.count >= 3 {
                    return "\(parts[parts.count - 3]).\(twoPartSuffix)"
                }
            }
        }
        
        // Tek parçalı suffix (örn: com, net)
        // son iki parçayı döndür
        return "\(parts[parts.count - 2]).\(parts[parts.count - 1])"
    }
    
    /// İki domain'in eşleşip eşleşmediğini kontrol eder
    /// - Parameters:
    ///   - domain1: Birinci domain (credential'dan)
    ///   - domain2: İkinci domain (service identifier'dan)
    /// - Returns: Eşleşme durumu
    static func domainsMatch(_ domain1: String?, _ domain2: String?) -> Bool {
        guard let d1 = extractDomain(from: domain1),
              let d2 = extractDomain(from: domain2) else {
            return false
        }
        
        // Tam eşleşme
        if d1 == d2 {
            return true
        }
        
        // Registrable domain eşleşmesi
        let reg1 = extractRegistrableDomain(from: d1)
        let reg2 = extractRegistrableDomain(from: d2)
        
        if reg1 == reg2 {
            return true
        }
        
        // Subdomain eşleşmesi (örn: login.instagram.com vs instagram.com)
        if d1.hasSuffix(".\(d2)") || d2.hasSuffix(".\(d1)") {
            return true
        }
        
        return false
    }
    
    /// Service identifier listesine göre credentials filtreler
    /// - Parameters:
    ///   - credentials: Filtrelenecek credentials
    ///   - serviceIdentifiers: Service identifier'lar
    /// - Returns: Eşleşen credentials
    static func filterCredentials(
        _ credentials: [AutofillCredential],
        for serviceIdentifiers: [String]
    ) -> [AutofillCredential] {
        guard !serviceIdentifiers.isEmpty else {
            return credentials
        }
        
        return credentials.filter { credential in
            let credentialDomain = extractDomain(from: credential.website)
            return serviceIdentifiers.contains { identifier in
                domainsMatch(credentialDomain, identifier)
            }
        }
    }
}
