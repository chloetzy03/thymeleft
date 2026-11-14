import Foundation

/// The chef of the Add / Edit screen: checks the rules, then saves.
@MainActor
final class AddEditItemInteractor: AddEditItemInteractorInput {

    weak var output: AddEditItemInteractorOutput?

    private let repository: PantryRepository
    private let dateProvider: DateProviding
    private let settingsStore: SettingsStore
    private let reminders: ReminderServicing
    private let photoStore: PhotoStoring

    init(repository: PantryRepository,
         dateProvider: DateProviding,
         settingsStore: SettingsStore,
         reminders: ReminderServicing,
         photoStore: PhotoStoring) {
        self.repository = repository
        self.dateProvider = dateProvider
        self.settingsStore = settingsStore
        self.reminders = reminders
        self.photoStore = photoStore
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

        // Photo: save a new picture first (so a failure stops us before anything changes).
        var photoFileName = existing?.photoFileName
        var newPhotoFileName: String?
        switch draft.photo {
        case .keep:
            break
        case .remove:
            photoFileName = nil
        case .replace(let data):
            do {
                newPhotoFileName = try photoStore.savePhoto(data)
                photoFileName = newPhotoFileName
            } catch {
                output?.didFail(error)
                return
            }
        }

        // When editing we keep the item's original id and "date added".
        let item = PantryItem(id: existing?.id ?? UUID(),
                              name: name,
                              quantity: draft.quantity,
                              location: draft.location,
                              expiryDate: draft.expiryDate,
                              reminder: draft.reminder,
                              photoFileName: photoFileName,
                              createdAt: existing?.createdAt ?? dateProvider.now)
        do {
            try repository.save(item)
        } catch {
            // The item wasn't saved, so the new picture we just stored would be left over. Remove it.
            if let newPhotoFileName { photoStore.deletePhoto(named: newPhotoFileName) }
            output?.didFail(error)
            return
        }

        // Saved! Now the old picture (if replaced or removed) can go.
        if let oldPhoto = existing?.photoFileName, oldPhoto != photoFileName {
            photoStore.deletePhoto(named: oldPhoto)
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
