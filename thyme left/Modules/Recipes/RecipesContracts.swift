import Foundation

// The "who may ask whom" rulebook for the Recipes screen.

struct RecipeRowViewModel: Equatable {
    let id: String
    let title: String
    let imageURL: URL?
    let usesText: String        // "Uses Milk, Spinach"
    let missingText: String     // "Missing: cream" or "You have everything"
    /// True when something is missing (the view colours the line amber). Never compare the words: they change per language.
    var hasMissing = false
    let accessibilityText: String
}

struct RecipesScreenViewModel: Equatable {
    /// "Rescue these first: Milk, Spinach" (nil when nothing is close to expiring)
    let rescueSummary: String?
    /// Shown when we couldn't reach the recipe service and are showing saved recipes.
    let banner: String?
    let rows: [RecipeRowViewModel]
    /// The "Use up first / Best match" switch only makes sense for suggestions, not for search results.
    var showsSortControl = true
}

enum RecipesFailure: Equatable {
    case offlineAndNothingSaved
    case problem
}

// MARK: - View (the waiter)

@MainActor
protocol RecipesViewProtocol: AnyObject {
    func showSortModes(titles: [String], selectedIndex: Int)
    func showLoading()
    func showRecipes(_ screen: RecipesScreenViewModel)
    func showMessage(emoji: String, title: String, message: String, buttonTitle: String?)
    /// Tells the screen it's now showing search results (or suggestions again).
    func showSearchStatus(_ text: String?)
}

// MARK: - Presenter (the manager)

@MainActor
protocol RecipesPresenterProtocol: AnyObject {
    func viewDidLoad()
    func viewWillAppear()
    func didSelectSort(at index: Int)
    func didSelectRecipe(id: String)
    func didTapRetry()
    /// Called on every keystroke in the search bar; the Presenter waits for a pause in typing.
    func didChangeSearchText(_ text: String)
    /// The user pressed Search on the keyboard: search right away.
    func didSubmitSearch(_ text: String)
    func didCancelSearch()
}

// MARK: - Interactor (the chef)

@MainActor
protocol RecipesInteractorInput: AnyObject {
    func loadRecipes(sort: RecipeSortMode)
    /// Re-orders what we already have (no new network calls).
    func changeSort(_ sort: RecipeSortMode)
    /// Finds recipes by dish name or ingredient, whatever your pantry holds.
    func search(query: String)
}

@MainActor
protocol RecipesInteractorOutput: AnyObject {
    /// `isOffline` is true when these came from the saved copies.
    func didLoad(matches: [RecipeMatch], rescueItemNames: [String], isOffline: Bool)
    func didFindNoPantryItems()
    func didFindNoRecipes()
    func didFail(_ failure: RecipesFailure)
    func didLoadSearch(matches: [RecipeMatch], query: String, isOffline: Bool)
    func didFindNoSearchResults(query: String)
    func didFailSearch(_ failure: RecipesFailure)
}

// MARK: - Router (the host)

@MainActor
protocol RecipesRouterProtocol: AnyObject {
    func showRecipe(_ match: RecipeMatch)
}
