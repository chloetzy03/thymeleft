import Foundation

/// The chef of the Pantry screen: loads items, works out each countdown, sorts them.
/// (Translation: all the thinking happens here, and nothing here knows about screens.)
@MainActor
final class PantryListInteractor: PantryListInteractorInput {

    /// Weak = "don't hold on tight", so Interactor and Presenter can't trap each other in memory.
    weak var output: PantryListInteractorOutput?

    private let repository: PantryRepository
    private let policy: ExpiryPolicy
    private let dateProvider: DateProviding
    private let calendar: Calendar

    init(repository: PantryRepository,
         policy: ExpiryPolicy,
         dateProvider: DateProviding,
         calendar: Calendar = .current) {
        self.repository = repository
        self.policy = policy
        self.dateProvider = dateProvider
        self.calendar = calendar
    }

    func loadItems(in location: StorageLocation?) {
        do {
            let now = dateProvider.now
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
            output?.didDeleteItem()
        } catch {
            output?.didFail(error)
        }
    }
}
