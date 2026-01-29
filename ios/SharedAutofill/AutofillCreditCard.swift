import Foundation

struct AutofillCreditCard: Codable, Identifiable {
    let id: Int
    let cardHolderName: String
    let cardNumber: String
    let expiryDate: String
    let cvv: String
    let displayName: String?

    var maskedNumber: String {
        guard cardNumber.count >= 4 else { return cardNumber }
        let lastFour = String(cardNumber.suffix(4))
        return "•••• \(lastFour)"
    }

    var formattedDisplayName: String {
        if let displayName, !displayName.isEmpty {
            return displayName
        }
        return maskedNumber
    }

    var cardType: CardType {
        CardType.detect(from: cardNumber)
    }

    enum CardType: String, Codable {
        case visa = "Visa"
        case mastercard = "Mastercard"
        case amex = "American Express"
        case discover = "Discover"
        case unknown = "Card"

        static func detect(from number: String) -> CardType {
            let digits = number.filter { $0.isNumber }
            guard let firstDigit = digits.first else { return .unknown }

            switch firstDigit {
            case "4":
                return .visa
            case "5":
                if digits.count >= 2 {
                    let secondDigit = digits[digits.index(after: digits.startIndex)]
                    if "12345".contains(secondDigit) {
                        return .mastercard
                    }
                }
                return .unknown
            case "3":
                if digits.count >= 2 {
                    let secondDigit = digits[digits.index(after: digits.startIndex)]
                    if "47".contains(secondDigit) {
                        return .amex
                    }
                }
                return .unknown
            case "6":
                if digits.hasPrefix("6011") || digits.hasPrefix("65") {
                    return .discover
                }
                return .unknown
            default:
                return .unknown
            }
        }
    }
}
