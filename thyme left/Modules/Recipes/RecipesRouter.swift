import UIKit

/// The host of the Recipes screen: opens a recipe's detail screen.
@MainActor
final class RecipesRouter: RecipesRouterProtocol {

    weak var viewController: UIViewController?
    private let makeDetail: (RecipeMatch) -> UIViewController

    init(makeDetail: @escaping (RecipeMatch) -> UIViewController) {
        self.makeDetail = makeDetail
    }

    func showRecipe(_ match: RecipeMatch) {
        viewController?.navigationController?.pushViewController(makeDetail(match), animated: true)
    }
}

/// Plugs the five VIPER parts of the Recipes screen together.
@MainActor
enum RecipesBuilder {

    static func build(repository: PantryRepository,
                      settingsStore: SettingsStore,
                      dateProvider: DateProviding,
                      service: RecipeService,
                      cache: RecipeCaching,
                      imageLoader: RemoteImageLoading) -> UIViewController {
        let view = RecipesViewController(imageLoader: imageLoader)
        let router = RecipesRouter { match in RecipeDetailBuilder.build(match: match, imageLoader: imageLoader) }
        let interactor = RecipesInteractor(repository: repository, settingsStore: settingsStore,
                                           dateProvider: dateProvider, service: service, cache: cache)
        let presenter = RecipesPresenter(view: view, interactor: interactor, router: router)
        view.presenter = presenter
        interactor.output = presenter
        router.viewController = view
        return view
    }
}
