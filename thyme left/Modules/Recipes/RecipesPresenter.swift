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

    init(view: RecipesViewProtocol, interactor: RecipesInteractorInput, router: RecipesRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }

    // MARK: From the View

    func viewDidLoad() {
        view?.showSortModes(titles: RecipeSortMode.allCases.map(\.title), selectedIndex: sort.rawValue)
    }

    func viewWillAppear() {
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
        guard let match = matches.first(where: { $0.recipe.id == id }) else { return }
        router.showRecipe(match)
    }

    func didTapRetry() {
        view?.showLoading()
        interactor.loadRecipes(sort: sort)
    }

    // MARK: From the Interactor

    func didLoad(matches: [RecipeMatch], rescueItemNames: [String], isOffline: Bool) {
        hasLoadedOnce = true
        self.matches = matches
        view?.showRecipes(RecipesScreenViewModel(
            rescueSummary: rescueItemNames.isEmpty ? nil : "Rescue these first: " + rescueItemNames.joined(separator: ", "),
            banner: isOffline ? "Can't reach the recipe service right now. Showing recipes saved on your phone." : nil,
            rows: matches.map(row(for:))))
    }

    func didFindNoPantryItems() {
        hasLoadedOnce = true
        matches = []
        view?.showMessage(emoji: "🥕", title: "Add some food first",
                          message: "Add what's in your kitchen and we'll suggest recipes that use it up.",
                          buttonTitle: nil)
    }

    func didFindNoRecipes() {
        hasLoadedOnce = true
        matches = []
        view?.showMessage(emoji: "🍳", title: "No recipes found yet",
                          message: "We couldn't find a recipe that uses your food. Try adding a few more basics like eggs, rice or onions.",
                          buttonTitle: "Try again")
    }

    func didFail(_ failure: RecipesFailure) {
        hasLoadedOnce = true
        matches = []
        switch failure {
        case .offlineAndNothingSaved:
            view?.showMessage(emoji: "📡", title: "You're offline",
                              message: "Recipes need the internet the first time. Once you've seen some, they're saved on your phone for later.",
                              buttonTitle: "Try again")
        case .problem:
            view?.showMessage(emoji: "🫠", title: "Something went wrong",
                              message: "We couldn't load recipes. Please try again in a moment.",
                              buttonTitle: "Try again")
        }
    }

    // MARK: Helpers

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
