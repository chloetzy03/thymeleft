import Foundation

/// The manager of the Recipes screen: words for rows, banners and messages.
@MainActor
final class RecipesPresenter: RecipesPresenterProtocol, RecipesInteractorOutput {

    private weak var view: RecipesViewProtocol?
    private let interactor: RecipesInteractorInput
    private let router: RecipesRouterProtocol

    private var sort: RecipeSortMode = .useItUpFirst
    private var matches: [RecipeMatch] = []
    private var hasLoadedOnce = false

    // Search state. `lastScreen` remembers what the suggestions looked like, to put them back afterwards.
    private var isSearching = false
    private var searchMatches: [RecipeMatch] = []
    private var searchTask: Task<Void, Never>?
    private var lastScreen: Screen?
    private let searchDelay: Duration

    private enum Screen {
        case recipes(RecipesScreenViewModel)
        case message(emoji: String, title: String, message: String, buttonTitle: String?)
    }

    /// `searchDelay` is the pause in typing we wait for before searching (tests use zero).
    init(view: RecipesViewProtocol, interactor: RecipesInteractorInput, router: RecipesRouterProtocol,
         searchDelay: Duration = .milliseconds(400)) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.searchDelay = searchDelay
    }

    // MARK: From the View

    func viewDidLoad() {
        view?.showSortModes(titles: RecipeSortMode.allCases.map(\.title), selectedIndex: sort.rawValue)
    }

    func viewWillAppear() {
        // Coming back from a recipe while searching? Keep the search results on screen.
        guard !isSearching else { return }
        // Your pantry may have changed since we last looked, so refresh each time the tab opens.
        if !hasLoadedOnce { view?.showLoading() }
        interactor.loadRecipes(sort: sort)
    }

    func didSelectSort(at index: Int) {
        guard let mode = RecipeSortMode(rawValue: index), mode != sort else { return }
        sort = mode
        view?.showSortModes(titles: RecipeSortMode.allCases.map(\.title), selectedIndex: sort.rawValue)
        interactor.changeSort(mode)
    }

    func didSelectRecipe(id: String) {
        let shown = isSearching ? searchMatches : matches
        guard let match = shown.first(where: { $0.recipe.id == id }) else { return }
        router.showRecipe(match)
    }

    // MARK: Search

    func didChangeSearchText(_ text: String) {
        searchTask?.cancel()
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { didCancelSearch(); return }
        isSearching = true
        searchTask = Task { [weak self, searchDelay] in
            // Wait for a pause in typing so we don't search on every letter.
            try? await Task.sleep(for: searchDelay)
            guard !Task.isCancelled else { return }
            self?.startSearch(query)
        }
    }

    func didSubmitSearch(_ text: String) {
        searchTask?.cancel()
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isSearching = true
        startSearch(query)
    }

    func didCancelSearch() {
        searchTask?.cancel()
        guard isSearching else { return }
        isSearching = false
        searchMatches = []
        view?.showSearchStatus(nil)
        switch lastScreen {
        case .recipes(let screen): view?.showRecipes(screen)
        case .message(let emoji, let title, let message, let buttonTitle):
            view?.showMessage(emoji: emoji, title: title, message: message, buttonTitle: buttonTitle)
        case nil:
            view?.showLoading()
            interactor.loadRecipes(sort: sort)
        }
    }

    private func startSearch(_ query: String) {
        view?.showSearchStatus("Searching for \u{201C}\(query)\u{201D}…")
        view?.showLoading()
        interactor.search(query: query)
    }

    func didTapRetry() {
        view?.showLoading()
        interactor.loadRecipes(sort: sort)
    }

    // MARK: From the Interactor

    func didLoad(matches: [RecipeMatch], rescueItemNames: [String], isOffline: Bool) {
        hasLoadedOnce = true
        self.matches = matches
        let screen = RecipesScreenViewModel(
            rescueSummary: rescueItemNames.isEmpty ? nil : "Rescue these first: " + rescueItemNames.joined(separator: ", "),
            banner: isOffline ? "Can't reach the recipe service right now. Showing recipes saved on your phone." : nil,
            rows: matches.map(row(for:)))
        lastScreen = .recipes(screen)
        if !isSearching { view?.showRecipes(screen) } // never replace search results with a slower suggestions load
    }

    func didLoadSearch(matches: [RecipeMatch], query: String, isOffline: Bool) {
        guard isSearching else { return }
        searchMatches = matches
        let count = matches.count == 1 ? "1 recipe" : "\(matches.count) recipes"
        view?.showSearchStatus(nil)
        view?.showRecipes(RecipesScreenViewModel(
            rescueSummary: "\(count) for \u{201C}\(query)\u{201D}",
            banner: isOffline ? "You're offline, so we only searched recipes saved on your phone." : nil,
            rows: matches.map(searchRow(for:)),
            showsSortControl: false))
    }

    func didFindNoSearchResults(query: String) {
        guard isSearching else { return }
        searchMatches = []
        view?.showSearchStatus(nil)
        view?.showMessage(emoji: "🔎", title: "No recipes found",
                          message: "Nothing matched \u{201C}\(query)\u{201D}. Try a dish name like \u{201C}pasta\u{201D} or an ingredient like \u{201C}chicken\u{201D}.",
                          buttonTitle: nil)
    }

    func didFailSearch(_ failure: RecipesFailure) {
        guard isSearching else { return }
        searchMatches = []
        view?.showSearchStatus(nil)
        switch failure {
        case .offlineAndNothingSaved:
            view?.showMessage(emoji: "📡", title: "You're offline",
                              message: "Searching needs the internet, unless the recipe is already saved on your phone.",
                              buttonTitle: nil)
        case .problem:
            view?.showMessage(emoji: "🫠", title: "Something went wrong",
                              message: "We couldn't search recipes. Please try again in a moment.",
                              buttonTitle: nil)
        }
    }

    func didFindNoPantryItems() {
        hasLoadedOnce = true
        matches = []
        show(.message(emoji: "🥕", title: "Add some food first",
                      message: "Add what's in your kitchen and we'll suggest recipes that use it up. You can still search for any recipe above.",
                      buttonTitle: nil))
    }

    func didFindNoRecipes() {
        hasLoadedOnce = true
        matches = []
        show(.message(emoji: "🍳", title: "No recipes found yet",
                      message: "We couldn't find a recipe that uses your food. Try adding a few more basics like eggs, rice or onions, or search for a dish above.",
                      buttonTitle: "Try again"))
    }

    func didFail(_ failure: RecipesFailure) {
        hasLoadedOnce = true
        matches = []
        switch failure {
        case .offlineAndNothingSaved:
            show(.message(emoji: "📡", title: "You're offline",
                          message: "Recipes need the internet the first time. Once you've seen some, they're saved on your phone for later.",
                          buttonTitle: "Try again"))
        case .problem:
            show(.message(emoji: "🫠", title: "Something went wrong",
                          message: "We couldn't load recipes. Please try again in a moment.",
                          buttonTitle: "Try again"))
        }
    }

    // MARK: Helpers

    /// Shows a message, unless the user is in the middle of a search (then it's only remembered for later).
    private func show(_ screen: Screen) {
        lastScreen = screen
        guard !isSearching, case .message(let emoji, let title, let message, let buttonTitle) = screen else { return }
        view?.showMessage(emoji: emoji, title: title, message: message, buttonTitle: buttonTitle)
    }

    /// For search results the useful fact is "how much of this do I already have?".
    private func searchRow(for match: RecipeMatch) -> RecipeRowViewModel {
        let have = match.ingredientAvailability.filter(\.have).count
        let total = match.ingredientAvailability.count
        let uses = total == 0 ? "No ingredient list" : "You have \(have) of \(total) ingredients"
        let missing = match.missingIngredients.isEmpty ? "You have everything" : "Missing: " + list(match.missingIngredients, limit: 3)
        return RecipeRowViewModel(
            id: match.recipe.id,
            title: match.recipe.name,
            imageURL: match.recipe.imageURL,
            usesText: uses,
            missingText: total == 0 ? "" : missing,
            accessibilityText: "\(match.recipe.name). \(uses). \(missing)")
    }

    private func row(for match: RecipeMatch) -> RecipeRowViewModel {
        let uses = list(match.usedItemNames, limit: 3)
        let missing = match.missingIngredients.isEmpty ? "You have everything" : "Missing: " + list(match.missingIngredients, limit: 3)
        return RecipeRowViewModel(
            id: match.recipe.id,
            title: match.recipe.name,
            imageURL: match.recipe.imageURL,
            usesText: "Uses " + uses,
            missingText: missing,
            accessibilityText: "\(match.recipe.name). Uses \(uses). \(missing)")
    }

    /// "Milk, Eggs, Spinach and 2 more"
    private func list(_ names: [String], limit: Int) -> String {
        guard names.count > limit else { return names.joined(separator: ", ") }
        return names.prefix(limit).joined(separator: ", ") + " and \(names.count - limit) more"
    }
}
