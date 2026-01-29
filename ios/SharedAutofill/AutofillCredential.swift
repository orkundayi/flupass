import AuthenticationServices
import Foundation

struct AutofillCredential: Codable, Identifiable {
    let id: Int
    let title: String
    let username: String
    let password: String
    let website: String?

    var displayName: String {
        // Önce website'dan okunabilir isim çıkar
        if let website, !website.isEmpty {
            if let domain = DomainMatcher.extractDomain(from: website) {
                return domain
            }
            return website
        }
        if !title.isEmpty {
            return title
        }
        return username
    }

    var domainIdentifier: String {
        guard let website, !website.isEmpty else {
            return "app.flupass"
        }

        // DomainMatcher ile daha doğru domain çıkarımı
        if let domain = DomainMatcher.extractDomain(from: website) {
            return domain
        }

        return "app.flupass"
    }
    
    /// Registrable domain (örn: mail.google.com -> google.com)
    var registrableDomain: String {
        let domain = domainIdentifier
        guard domain != "app.flupass" else { return domain }
        return DomainMatcher.extractRegistrableDomain(from: domain)
    }

    func makePasswordCredential() -> ASPasswordCredential {
        ASPasswordCredential(user: username, password: password)
    }

    func makeIdentity() -> ASPasswordCredentialIdentity {
        let serviceIdentifier = ASCredentialServiceIdentifier(identifier: domainIdentifier, type: .domain)
        return ASPasswordCredentialIdentity(serviceIdentifier: serviceIdentifier, user: username, recordIdentifier: String(id))
    }
    
    /// Verilen domain ile eşleşip eşleşmediğini kontrol eder
    func matchesDomain(_ otherDomain: String) -> Bool {
        return DomainMatcher.domainsMatch(website, otherDomain)
    }
}
