import Foundation

// The "who may ask whom" rulebook for the Add / Edit screen.
// (Same pattern as the Pantry screen: View -> Presenter -> Interactor, answers come back.)

/// What the user can do with the item's photo.
enum PhotoOption: Equatable {
    case takePhoto, chooseFromLibrary, removePhoto
}

/// Where a new photo comes from.
enum PhotoSource: Equatable {
    case camera, library
}

/// Everything the form needs to draw itself the first time.
struct AddEditFormViewModel: Equatable {
    let title: String
    let saveButtonTitle: String
    let name: String
    let emoji: String
    let quantity: Int
    let quantityRange: ClosedRange<Int>
    let locationTitles: [String]
    let selectedLocationIndex: Int
    let reminderTitles: [String]
    let selectedReminderIndex: Int
    /// The item's current photo, or nil to show the emoji.
    let photoData: Data?
    let expiryDate: Date
    let quickDateTitles: [String]
}

// MARK: - View (the waiter)

@MainActor
protocol AddEditItemViewProtocol: AnyObject {
    func showForm(_ form: AddEditFormViewModel)
    func showEmoji(_ emoji: String)
    /// `nil` goes back to showing the emoji.
    func showPhoto(_ data: Data?)
    func showPhotoOptions(_ options: [PhotoOption])
    func presentPhotoPicker(_ source: PhotoSource)
    func showExpiryDate(_ date: Date)
    /// `nil` clears the message.
    func showNameError(_ message: String?)
    func showError(message: String)
    /// Our own friendly "Get reminders?" explanation, shown before iOS's pop-up.
    func showReminderPrimer()
}

// MARK: - Presenter (the manager)

@MainActor
protocol AddEditItemPresenterProtocol: AnyObject {
    func viewDidLoad()
    func viewDidAppear()
    func didTapScan()
    func didScan(_ result: ScanResult)
    func nameChanged(_ text: String)
    func didSelectQuickDate(at index: Int)
    func didTapPhoto()
    func didSelectPhotoOption(_ option: PhotoOption)
    func didPickPhoto(_ data: Data)
    func didTapSave(name: String, quantity: Int, locationIndex: Int, reminderIndex: Int, expiryDate: Date)
    func didRespondToReminderPrimer(allow: Bool)
    func didTapCancel()
}

// MARK: - Interactor (the chef)

@MainActor
protocol AddEditItemInteractorInput: AnyObject {
    /// `existing` is the item being edited, or `nil` when adding a new one.
    func save(_ draft: PantryItemDraft, replacing existing: PantryItem?)
    func requestReminderPermission()
}

@MainActor
protocol AddEditItemInteractorOutput: AnyObject {
    /// `shouldExplainReminders` is true when we should show our reminder explainer first.
    func didSave(shouldExplainReminders: Bool)
    func didFinishReminderPermission()
    func didFailValidation(_ error: ItemValidationError)
    func didFail(_ error: Error)
}

// MARK: - Router (the host)

@MainActor
protocol AddEditItemRouterProtocol: AnyObject {
    func showScanner(onResult: @escaping (ScanResult) -> Void)
    func close()
}
