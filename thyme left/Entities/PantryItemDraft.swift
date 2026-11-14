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
    var photo: PhotoChange = .keep
}

/// What the user did about the photo while filling in the form.
enum PhotoChange: Equatable {
    case keep               // leave the photo as it was (or still none)
    case replace(Data)      // a new picture was taken or picked
    case remove             // go back to the emoji
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
