import Foundation

/// What the user has typed into the form, before we've checked it.
/// (Translation: a rough copy. It only becomes a real `PantryItem` once the Interactor
/// has checked it follows the rules.)
struct PantryItemDraft: Equatable {
    var name: String
    var quantity: Int
    var location: StorageLocation
    var expiryDate: Date
    var reminder: ReminderPreference = .useDefault
}

/// The rules an item must follow before we save it.
enum PantryItemRules {
    static let maxNameLength = 40
    static let quantityRange = 1...99
}

/// Why a draft was turned down.
enum ItemValidationError: Error, Equatable {
    case emptyName
    case nameTooLong(max: Int)
    case invalidQuantity
}
