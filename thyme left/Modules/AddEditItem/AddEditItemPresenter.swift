import Foundation

/// The manager of the Add / Edit screen: sets up the form and turns results into messages.
@MainActor
final class AddEditItemPresenter: AddEditItemPresenterProtocol, AddEditItemInteractorOutput {

    /// The shortcut buttons under the date picker.
    private struct QuickDate {
        let title: String
        let offset: DateComponents
    }
    private let quickDates = [
        QuickDate(title: "Tomorrow", offset: DateComponents(day: 1)),
        QuickDate(title: "3 days", offset: DateComponents(day: 3)),
        QuickDate(title: "1 week", offset: DateComponents(day: 7)),
        QuickDate(title: "1 month", offset: DateComponents(month: 1))
    ]

    /// A brand-new item starts with an expiry date one week from today.
    private static let defaultDaysUntilExpiry = 7

    private weak var view: AddEditItemViewProtocol?
    private let interactor: AddEditItemInteractorInput
    private let router: AddEditItemRouterProtocol
    private let iconProvider: FoodIconProviding
    private let dateProvider: DateProviding
    private let calendar: Calendar
    private let existingItem: PantryItem?
    /// Called after a successful save, so the previous screen can refresh itself.
    private let onSaved: () -> Void

    private let locations = StorageLocation.allCases

    init(view: AddEditItemViewProtocol,
         interactor: AddEditItemInteractorInput,
         router: AddEditItemRouterProtocol,
         iconProvider: FoodIconProviding,
         dateProvider: DateProviding,
         existingItem: PantryItem?,
         calendar: Calendar = .current,
         onSaved: @escaping () -> Void) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.iconProvider = iconProvider
        self.dateProvider = dateProvider
        self.existingItem = existingItem
        self.calendar = calendar
        self.onSaved = onSaved
    }

    // MARK: Things the View tells us

    func viewDidLoad() {
        let name = existingItem?.name ?? ""
        let location = existingItem?.location ?? .fridge
        let defaultExpiry = calendar.date(byAdding: .day, value: Self.defaultDaysUntilExpiry,
                                          to: dateProvider.now) ?? dateProvider.now

        view?.showForm(AddEditFormViewModel(
            title: existingItem == nil ? "Add item" : "Edit item",
            saveButtonTitle: existingItem == nil ? "Add to pantry" : "Save changes",
            name: name,
            emoji: iconProvider.emoji(for: name),
            quantity: existingItem?.quantity ?? 1,
            quantityRange: PantryItemRules.quantityRange,
            locationTitles: locations.map(\.displayName),
            selectedLocationIndex: locations.firstIndex(of: location) ?? 0,
            expiryDate: existingItem?.expiryDate ?? defaultExpiry,
            quickDateTitles: quickDates.map(\.title)))
    }

    func nameChanged(_ text: String) {
        view?.showEmoji(iconProvider.emoji(for: text))
        view?.showNameError(nil) // the user is fixing it, so hide the old message
    }

    func didSelectQuickDate(at index: Int) {
        guard quickDates.indices.contains(index),
              let date = calendar.date(byAdding: quickDates[index].offset, to: dateProvider.now) else { return }
        view?.showExpiryDate(date)
    }

    func didTapSave(name: String, quantity: Int, locationIndex: Int, expiryDate: Date) {
        guard locations.indices.contains(locationIndex) else { return }
        let draft = PantryItemDraft(name: name, quantity: quantity,
                                    location: locations[locationIndex], expiryDate: expiryDate)
        interactor.save(draft, replacing: existingItem)
    }

    func didTapCancel() {
        router.close()
    }

    // MARK: Things the Interactor tells us

    func didSave() {
        onSaved()
        router.close()
    }

    func didFailValidation(_ error: ItemValidationError) {
        switch error {
        case .emptyName:
            view?.showNameError("Please give this item a name.")
        case .nameTooLong(let max):
            view?.showNameError("That name is too long. Please use \(max) characters or fewer.")
        case .invalidQuantity:
            let range = PantryItemRules.quantityRange
            view?.showError(message: "Quantity must be between \(range.lowerBound) and \(range.upperBound).")
        }
    }

    func didFail(_ error: Error) {
        view?.showError(message: "We couldn't save this item. Please try again.")
    }
}
