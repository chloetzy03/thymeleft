import Foundation

// The "who may ask whom" rulebook for the Recipes screen.

struct RecipeRowViewModel: Equatable {
    let id: String
    let title: String
    let imageURL: URL?
    let usesText: String        // "Uses Milk, Spinach"
    let missingText: String     // "Missing: cream" or "You have everything"
    let accessibilityText: String
}

struct RecipesScreenViewModel: Equatable {
    /// "Rescue these first: Milk, Spinach" (nil when nothing is close to expiring)
    let rescueSummary: String?
    /// Shown when we couldn't reach the recipe service and are showing saved recipes.
    let banner: String?
    let rows: [RecipeRowViewModel]
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
}

// MARK: - Presenter (the manager)

@MainActor
protocol RecipesPresenterProtocol: AnyObject {
    func viewDidLoad()
    func viewWillAppear()
    func didSelectSort(at index: Int)
    func didSelectRecipe(id: String)
    func didTapRetry()
}

// MARK: - Interactor (the chef)

@MainActor
protocol RecipesInteractorInput: AnyObject {
    func loadRecipes(sort: RecipeSortMode)
    /// Re-orders what we already have (no new network calls).
    func changeSort(_ sort: RecipeSortMode)
}

@MainActor
protocol RecipesInteractorOutput: AnyObject {
    /// `isOffline` is true when these came from the saved copies.
    func didLoad(matches: [RecipeMatch], rescueItemNames: [String], isOffline: Bool)
    func didFindNoPantryItems()
    func didFindNoRecipes()
    func didFail(_ failure: RecipesFailure)
}

// MARK: - Router (the host)

@MainActor
protocol RecipesRouterProtocol: AnyObject {
    func showRecipe(_ match: RecipeMatch)
}
