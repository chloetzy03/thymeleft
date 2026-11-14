import Foundation

/// The chef of the Add / Edit screen: checks the rules, then saves.
@MainActor
final class AddEditItemInteractor: AddEditItemInteractorInput {

    weak var output: AddEditItemInteractorOutput?

    private let repository: PantryRepository
    private let dateProvider: DateProviding

    init(repository: PantryRepository, dateProvider: DateProviding) {
        self.repository = repository
        self.dateProvider = dateProvider
    }

    func save(_ draft: PantryItemDraft, replacing existing: PantryItem?) {
        // Remove accidental spaces at the start and end ("  Milk " -> "Milk").
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else {
            output?.didFailValidation(.emptyName)
            return
        }
        guard name.count <= PantryItemRules.maxNameLength else {
            output?.didFailValidation(.nameTooLong(max: PantryItemRules.maxNameLength))
            return
        }
        guard PantryItemRules.quantityRange.contains(draft.quantity) else {
            output?.didFailValidation(.invalidQuantity)
            return
        }

        // When editing we keep the item's original id and "date added".
        let item = PantryItem(id: existing?.id ?? UUID(),
                              name: name,
                              quantity: draft.quantity,
                              location: draft.location,
                              expiryDate: draft.expiryDate,
                              createdAt: existing?.createdAt ?? dateProvider.now)
        do {
            try repository.save(item)
            output?.didSave()
        } catch {
            output?.didFail(error)
        }
    }
}
