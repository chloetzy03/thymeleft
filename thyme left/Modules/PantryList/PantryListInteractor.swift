import Foundation

/// The chef of the Pantry screen: loads items, works out each countdown, sorts them.
/// (Translation: all the thinking happens here, and nothing here knows about screens.)
@MainActor
final class PantryListInteractor: PantryListInteractorInput {

    /// Weak = "don't hold on tight", so Interactor and Presenter can't trap each other in memory.
    weak var output: PantryListInteractorOutput?

    private let repository: PantryRepository
    private let settingsStore: SettingsStore
    private let dateProvider: DateProviding
    private let reminders: ReminderServicing
    private let calendar: Calendar

    init(repository: PantryRepository,
         settingsStore: SettingsStore,
         dateProvider: DateProviding,
         reminders: ReminderServicing,
         calendar: Calendar = .current) {
        self.repository = repository
        self.settingsStore = settingsStore
        self.dateProvider = dateProvider
        self.reminders = reminders
        self.calendar = calendar
    }

    func loadItems(in location: StorageLocation?) {
        do {
            let now = dateProvider.now
            // Read the red/amber thresholds fresh each time, so Settings changes apply instantly.
            let policy = settingsStore.load().expiryPolicy
            let items = try repository.fetchAll()
                .filter { location == nil || $0.location == location }
                .map { item -> ExpiringItem in
                    let days = policy.daysRemaining(until: item.expiryDate, from: now, calendar: calendar)
                    return ExpiringItem(item: item, daysRemaining: days, status: policy.status(forDaysRemaining: days))
                }
                // Soonest-to-expire first (already-expired ones come out on top). Ties go A to Z.
                .sorted {
                    if $0.daysRemaining != $1.daysRemaining { return $0.daysRemaining < $1.daysRemaining }
                    return $0.item.name.localizedCaseInsensitiveCompare($1.item.name) == .orderedAscending
                }
            output?.didLoad(items)
        } catch {
            output?.didFail(error)
        }
    }

    func deleteItem(id: UUID) {
        do {
            try repository.delete(id: id)
            reminders.reschedule() // the deleted item's reminder must go too
            output?.didDeleteItem()
        } catch {
            output?.didFail(error)
        }
    }
}
