import Foundation

/// What the date on the pack means.
/// (Translation: "Best before" is about taste and quality; "Use by" is about safety.
/// A pack past its best-before date is often fine; a pack past its use-by date should not be eaten.)
enum DateType: String, Codable, CaseIterable {
    case bestBefore
    case useBy

    var displayName: String {
        switch self {
        case .bestBefore: return "Best before"
        case .useBy: return "Use by"
        }
    }
}
