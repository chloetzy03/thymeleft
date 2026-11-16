import UIKit

/// The host of the Home screen: switches to another tab.
@MainActor
final class HomeRouter: HomeRouterProtocol {

    private let selectRecipes: () -> Void
    private let selectPantry: () -> Void

    init(selectRecipes: @escaping () -> Void, selectPantry: @escaping () -> Void) {
        self.selectRecipes = selectRecipes
        self.selectPantry = selectPantry
    }

    func showRecipes() { selectRecipes() }
    func showPantry() { selectPantry() }
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
                      selectRecipes: @escaping () -> Void,
                      selectPantry: @escaping () -> Void) -> UIViewController {
        let view = HomeViewController(photoCache: photoCache)
        let router = HomeRouter(selectRecipes: selectRecipes, selectPantry: selectPantry)
        let interactor = HomeInteractor(repository: repository, outcomes: outcomes,
                                        settingsStore: settingsStore, dateProvider: dateProvider)
        let presenter = HomePresenter(view: view, interactor: interactor, router: router,
                                      iconProvider: iconProvider, dateProvider: dateProvider)
        view.presenter = presenter
        interactor.output = presenter
        return view
    }
}
