import Foundation

/// The chef of the Recipes screen: works out which recipes fit your pantry.
/// Steps: pick your usable items -> map each to the recipe database's ingredient name ->
/// search -> fetch the best recipes' details -> save them -> rank them.
/// If the internet fails it falls back to recipes saved earlier.
@MainActor
final class RecipesInteractor: RecipesInteractorInput {

    weak var output: RecipesInteractorOutput?

    /// We search for at most this many of your items (soonest-to-expire first) and fetch this many recipes.
    static let maxSearchedItems = 8
    static let maxRecipes = 12

    private let repository: PantryRepository
    private let settingsStore: SettingsStore
    private let dateProvider: DateProviding
    private let service: RecipeService
    private let cache: RecipeCaching
    private let matcher = IngredientMatcher()
    private let ranker = RecipeRanker()
    private let calendar: Calendar

    private var knownIngredients: [String]?
    private var candidates: [Recipe] = []
    private var pantry: [ExpiringItem] = []
    private var isOffline = false
    private var loadTask: Task<Void, Never>?
    /// A newer request makes older, slower ones stop reporting.
    private var generation = 0

    init(repository: PantryRepository,
         settingsStore: SettingsStore,
         dateProvider: DateProviding,
         service: RecipeService,
         cache: RecipeCaching,
         calendar: Calendar = .current) {
        self.repository = repository
        self.settingsStore = settingsStore
        self.dateProvider = dateProvider
        self.service = service
        self.cache = cache
        self.calendar = calendar
    }

    func loadRecipes(sort: RecipeSortMode) {
        loadTask?.cancel()
        generation += 1
        let myGeneration = generation
        loadTask = Task { await run(sort: sort, generation: myGeneration) }
    }

    func changeSort(_ sort: RecipeSortMode) {
        guard !candidates.isEmpty else { return }
        deliver(sort: sort)
    }

    // MARK: - The work

    private func run(sort: RecipeSortMode, generation myGeneration: Int) async {
        guard let usable = usablePantry() else { output?.didFail(.problem); return }
        guard !usable.isEmpty else { output?.didFindNoPantryItems(); return }
        pantry = usable

        do {
            let fetched = try await fetchOnline(for: usable)
            guard myGeneration == generation else { return }
            cache.store(fetched)
            candidates = fetched
            isOffline = false
        } catch {
            guard myGeneration == generation else { return }
            let saved = cache.allRecipes()
            guard !saved.isEmpty else {
                output?.didFail((error as? RecipeServiceError) == .offline ? .offlineAndNothingSaved : .problem)
                return
            }
            candidates = saved
            isOffline = true
        }
        guard myGeneration == generation else { return }
        deliver(sort: sort)
    }

    /// Your items that are still good (expired food is never suggested), soonest-to-expire first.
    private func usablePantry() -> [ExpiringItem]? {
        guard let items = try? repository.fetchAll() else { return nil }
        let policy = settingsStore.load().expiryPolicy
        let now = dateProvider.now
        return items
            .map { item -> ExpiringItem in
                let days = policy.daysRemaining(until: item.expiryDate, from: now, calendar: calendar)
                return ExpiringItem(item: item, daysRemaining: days, status: policy.status(forDaysRemaining: days))
            }
            .filter { $0.status != .expired }
            .sorted {
                if $0.daysRemaining != $1.daysRemaining { return $0.daysRemaining < $1.daysRemaining }
                return $0.item.name.localizedCaseInsensitiveCompare($1.item.name) == .orderedAscending
            }
    }

    private func fetchOnline(for usable: [ExpiringItem]) async throws -> [Recipe] {
        let known = try await ingredientNames()

        // Search once per distinct ingredient. Recipes found by items closer to expiry score higher.
        var searched = Set<String>()
        var scores: [String: Double] = [:]
        var succeeded = false
        var firstError: Error?
        for entry in usable {
            guard searched.count < Self.maxSearchedItems else { break }
            guard let keyword = matcher.searchKeyword(for: entry.item.name, knownIngredients: known),
                  searched.insert(keyword.lowercased()).inserted else { continue }
            do {
                let summaries = try await service.recipeSummaries(withIngredient: keyword)
                succeeded = true
                let weight = 1.0 / Double(1 + max(entry.daysRemaining, 0))
                for summary in summaries { scores[summary.id, default: 0] += weight }
            } catch {
                firstError = firstError ?? error
            }
        }
        if !succeeded, let firstError { throw firstError }

        let topIDs = scores.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(Self.maxRecipes).map(\.key)

        // Full details: use a saved copy when we have one, otherwise ask the service.
        let saved = Dictionary(uniqueKeysWithValues: cache.allRecipes().map { ($0.id, $0) })
        var recipes: [Recipe] = []
        var detailError: Error?
        for id in topIDs {
            if let copy = saved[id] { recipes.append(copy); continue }
            do { recipes.append(try await service.recipe(id: id)) } catch { detailError = detailError ?? error }
        }
        if recipes.isEmpty, let detailError { throw detailError }
        return recipes
    }

    private func ingredientNames() async throws -> [String] {
        if let knownIngredients { return knownIngredients }
        let names = try await service.knownIngredientNames()
        knownIngredients = names
        return names
    }

    private func deliver(sort: RecipeSortMode) {
        let matches = ranker.rank(recipes: candidates, pantry: pantry, mode: sort)
        guard !matches.isEmpty else { output?.didFindNoRecipes(); return }
        // Distinct names only: two cartons of milk are one "Milk" in the summary.
        var seen = Set<String>()
        let rescue = pantry.filter { $0.status.needsAttention }
            .map(\.item.name)
            .filter { seen.insert($0.lowercased()).inserted }
            .prefix(4)
        output?.didLoad(matches: matches, rescueItemNames: Array(rescue), isOffline: isOffline)
    }
}
