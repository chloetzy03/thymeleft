import Foundation

/// Writes an amount in the user's own currency, e.g. "$3" or "£34".
/// (Translation: no decimals for whole amounts, so "about $34" reads naturally.)
enum MoneyFormatter {
    static func string(_ amount: Double, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.maximumFractionDigits = amount.rounded() == amount ? 0 : 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}
