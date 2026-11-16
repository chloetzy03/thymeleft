import Foundation

/// The chef of the Home screen: gathers the numbers (what's about to expire, what you've saved).
@MainActor
final class HomeInteractor: HomeInteractorInput {

    weak var output: HomeInteractorOutput?

    /// How many "use soon" tiles Home shows.
    static let maxTiles = 3

    private let repository: PantryRepository
    private let outcomes: OutcomeRepository
    private let settingsStore: SettingsStore
    private let dateProvider: DateProviding
    private let calendar: Calendar

    init(repository: PantryRepository,
         outcomes: OutcomeRepository,
         settingsStore: SettingsStore,
         dateProvider: DateProviding,
         calendar: Calendar = .current) {
        self.repository = repository
        self.outcomes = outcomes
        self.settingsStore = settingsStore
        self.dateProvider = dateProvider
        self.calendar = calendar
    }

    func loadHome() {
        guard let items = try? repository.fetchAll(), let history = try? outcomes.fetchAll() else {
            output?.didFail()
            return
        }
        let settings = settingsStore.load()
        let policy = settings.expiryPolicy
        let now = dateProvider.now

        let entries = items
            .map { item -> ExpiringItem in
                let days = policy.daysRemaining(until: item.expiryDate, from: now, calendar: calendar)
                return ExpiringItem(item: item, daysRemaining: days, status: policy.status(forDaysRemaining: days))
            }
            .filter { $0.status.needsAttention }
            .sorted {
                if $0.daysRemaining != $1.daysRemaining { return $0.daysRemaining < $1.daysRemaining }
                return $0.item.name.localizedCaseInsensitiveCompare($1.item.name) == .orderedAscending
            }

        // "This month" means the calendar month we are in right now.
        let usedEntries = history.filter {
            $0.outcome == .used && calendar.isDate($0.date, equalTo: now, toGranularity: .month)
        }
        let usedThisMonth = usedEntries.count
        // Each item counts at its own price when we know it, otherwise at the user's average.
        let saved = usedEntries.reduce(0.0) { $0 + ($1.value ?? settings.averageItemValue) }

        output?.didLoad(HomeSnapshot(
            useSoon: Array(entries.prefix(Self.maxTiles)),
            attentionCount: entries.count,
            pantryCount: items.count,
            usedThisMonth: usedThisMonth,
            savedValue: settings.showMoneySaved ? saved : nil))
    }
}
