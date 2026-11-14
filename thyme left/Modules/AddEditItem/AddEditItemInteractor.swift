import Foundation

/// The chef of the Add / Edit screen: checks the rules, then saves.
@MainActor
final class AddEditItemInteractor: AddEditItemInteractorInput {

    weak var output: AddEditItemInteractorOutput?

    private let repository: PantryRepository
    private let dateProvider: DateProviding
    private let settingsStore: SettingsStore
    private let reminders: ReminderServicing

    init(repository: PantryRepository,
         dateProvider: DateProviding,
         settingsStore: SettingsStore,
         reminders: ReminderServicing) {
        self.repository = repository
        self.dateProvider = dateProvider
        self.settingsStore = settingsStore
        self.reminders = reminders
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
                              reminder: draft.reminder,
                              createdAt: existing?.createdAt ?? dateProvider.now)
        do {
            try repository.save(item)
        } catch {
            output?.didFail(error)
            return
        }

        reminders.reschedule()
        output?.didSave(shouldExplainReminders: shouldExplainReminders(for: item))
    }

    func requestReminderPermission() {
        Task {
            _ = await reminders.requestPermission()
            output?.didFinishReminderPermission()
        }
    }

    /// Show our explainer only once, only if the user would actually get a reminder for this
    /// item, and only if iOS hasn't been asked yet.
    private func shouldExplainReminders(for item: PantryItem) -> Bool {
        var settings = settingsStore.load()
        guard settings.notificationsEnabled,
              item.reminder != .never,
              reminders.permission == .notDetermined,
              !settings.hasSeenReminderPrimer else { return false }

        settings.hasSeenReminderPrimer = true
        settingsStore.save(settings)
        return true
    }
}
