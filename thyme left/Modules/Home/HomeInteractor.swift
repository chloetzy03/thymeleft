import Foundation

/// The chef of the Home screen: gathers the numbers (what's about to expire, what you've saved).
@MainActor
final class HomeInteractor: HomeInteractorInput {

    weak var output: HomeInteractorOutput?

    /// How many "use soon" tiles Home shows.
    static let maxTiles = 3
    /// How many days the "This week" strip covers.
    static let weekLength = 7

    private let repository: PantryRepository
    private let outcomes: OutcomeRepository
    private let settingsStore: SettingsStore
    private let dateProvider: DateProviding
    private let calendar: Calendar
    private let recipeCache: RecipeCaching?
    private let ranker = RecipeRanker()

    /// `recipeCache` is where the "tonight's idea" comes from (recipes you've already seen, so no waiting).
    init(repository: PantryRepository,
         outcomes: OutcomeRepository,
         settingsStore: SettingsStore,
         dateProvider: DateProviding,
         recipeCache: RecipeCaching? = nil,
         calendar: Calendar = .current) {
        self.recipeCache = recipeCache
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

        let allEntries = items
            .map { item -> ExpiringItem in
                let days = policy.daysRemaining(until: item.expiryDate, from: now, calendar: calendar)
                return ExpiringItem(item: item, daysRemaining: days, status: policy.status(forDaysRemaining: days))
            }
            .sorted {
                if $0.daysRemaining != $1.daysRemaining { return $0.daysRemaining < $1.daysRemaining }
                return $0.item.name.localizedCaseInsensitiveCompare($1.item.name) == .orderedAscending
            }
        let entries = allEntries.filter { $0.status.needsAttention }

        // The next 7 days, today first: how many items run out on each.
        let startOfToday = calendar.startOfDay(for: now)
        let week = (0..<Self.weekLength).map { offset -> HomeWeekDay in
            let date = calendar.date(byAdding: .day, value: offset, to: startOfToday) ?? startOfToday
            let count = allEntries.filter { $0.daysRemaining == offset }.count
            return HomeWeekDay(date: date, count: count, status: policy.status(forDaysRemaining: offset))
        }
        let pastCount = allEntries.filter { $0.daysRemaining < 0 }.count

        // Tonight's idea: the best "use up first" match among recipes the user has already seen.
        let usable = allEntries.filter { $0.status != .expired }
        let idea = recipeCache.flatMap { cache in
            ranker.rank(recipes: cache.allRecipes(), pantry: usable, mode: .useItUpFirst).first
        }.map { HomeRecipeIdea(name: $0.recipe.name, usedItemNames: $0.usedItemNames,
                               missingCount: $0.missingIngredients.count) }

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
            savedValue: settings.showMoneySaved ? saved : nil,
            week: week,
            pastCount: pastCount,
            recipeIdea: usable.contains(where: { $0.status.needsAttention }) ? idea : nil))
    }
}
