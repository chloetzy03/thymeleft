import Foundation

/// Where an item is kept at home.
/// (Translation: a fixed list of choices, so nobody can type "Frige" by accident.)
enum StorageLocation: String, CaseIterable, Codable {
    case fridge, pantry, freezer, counter

    var displayName: String {
        switch self {
        case .fridge: return String(localized: "Fridge")
        case .pantry: return String(localized: "Pantry")
        case .freezer: return String(localized: "Freezer")
        case .counter: return String(localized: "Counter")
        }
    }
}
