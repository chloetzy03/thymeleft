import UIKit

/// The host of the Pantry screen: knows how to move to other screens.
/// (Translation: the Presenter says "go to Add Item"; the Router knows how to actually do it.)
@MainActor
final class PantryListRouter: PantryListRouterProtocol {

    /// Weak so the Router doesn't keep the screen alive after it has been closed.
    weak var viewController: UIViewController?

    func showAddItem() {
        // Placeholder until Milestone 2 builds the real "Add item" module.
        let placeholder = PlaceholderViewController(
            title: "Add item",
            message: "Adding items by hand arrives in Milestone 2.")
        placeholder.title = "Add item"
        viewController?.navigationController?.pushViewController(placeholder, animated: true)
    }
}

/// Plugs the five VIPER parts together. (Translation: the "assembly line" that builds the
/// screen and introduces each part to its neighbours. Nobody else needs to know how.)
@MainActor
enum PantryListBuilder {

    static func build(repository: PantryRepository,
                      policy: ExpiryPolicy,
                      dateProvider: DateProviding,
                      iconProvider: FoodIconProviding) -> UIViewController {
        let view = PantryListViewController()
        let router = PantryListRouter()
        let interactor = PantryListInteractor(repository: repository, policy: policy, dateProvider: dateProvider)
        let presenter = PantryListPresenter(view: view, interactor: interactor, router: router, iconProvider: iconProvider)

        view.presenter = presenter
        interactor.output = presenter
        router.viewController = view
        return view
    }
}
