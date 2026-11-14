import Foundation

/// Where an item is kept at home.
/// (Translation: a fixed list of choices, so nobody can type "Frige" by accident.)
enum StorageLocation: String, CaseIterable, Codable {
    case fridge, pantry, freezer, counter

    var displayName: String {
        switch self {
        case .fridge: return "Fridge"
        case .pantry: return "Pantry"
        case .freezer: return "Freezer"
        case .counter: return "Counter"
        }
    }
}
