import UIKit

/// The host of the Home screen: switches to another tab.
@MainActor
final class HomeRouter: HomeRouterProtocol {

    private let selectRecipes: () -> Void
    private let selectPantry: () -> Void
    private let selectScan: () -> Void
    private let addItem: () -> Void

    init(selectRecipes: @escaping () -> Void, selectPantry: @escaping () -> Void,
         selectScan: @escaping () -> Void, addItem: @escaping () -> Void) {
        self.selectRecipes = selectRecipes
        self.selectPantry = selectPantry
        self.selectScan = selectScan
        self.addItem = addItem
    }

    func showRecipes() { selectRecipes() }
    func showPantry() { selectPantry() }
    func showScan() { selectScan() }
    func showAddItem() { addItem() }
}

/// Plugs the four VIPER parts of the Home screen together.
@MainActor
enum HomeBuilder {

    static func build(repository: PantryRepository,
                      outcomes: OutcomeRepository,
                      settingsStore: SettingsStore,
                      dateProvider: DateProviding,
                      iconProvider: FoodIconProviding,
                      photoCache: PhotoImageCache,
                      recipeCache: RecipeCaching,
                      selectRecipes: @escaping () -> Void,
                      selectPantry: @escaping () -> Void,
                      selectScan: @escaping () -> Void,
                      addItem: @escaping () -> Void) -> UIViewController {
        let view = HomeViewController(photoCache: photoCache)
        let router = HomeRouter(selectRecipes: selectRecipes, selectPantry: selectPantry,
                                selectScan: selectScan, addItem: addItem)
        let interactor = HomeInteractor(repository: repository, outcomes: outcomes,
                                        settingsStore: settingsStore, dateProvider: dateProvider,
                                        recipeCache: recipeCache)
        let presenter = HomePresenter(view: view, interactor: interactor, router: router,
                                      iconProvider: iconProvider, dateProvider: dateProvider)
        view.presenter = presenter
        interactor.output = presenter
        return view
    }
}
