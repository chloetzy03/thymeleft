import UIKit

/// The host of the Add / Edit screen: knows how to close it.
@MainActor
final class AddEditItemRouter: AddEditItemRouterProtocol {

    weak var viewController: UIViewController?

    func close() {
        viewController?.dismiss(animated: true)
    }
}

/// Plugs the five VIPER parts of the Add / Edit screen together.
@MainActor
enum AddEditItemBuilder {

    /// - Parameters:
    ///   - existing: the item to edit, or `nil` to add a new one.
    ///   - onSaved: called after a successful save (the previous screen uses it to refresh).
    static func build(existing: PantryItem?,
                      repository: PantryRepository,
                      dateProvider: DateProviding,
                      iconProvider: FoodIconProviding,
                      onSaved: @escaping () -> Void) -> UIViewController {
        let view = AddEditItemViewController()
        let router = AddEditItemRouter()
        let interactor = AddEditItemInteractor(repository: repository, dateProvider: dateProvider)
        let presenter = AddEditItemPresenter(view: view, interactor: interactor, router: router,
                                             iconProvider: iconProvider, dateProvider: dateProvider,
                                             existingItem: existing, onSaved: onSaved)
        view.presenter = presenter
        interactor.output = presenter
        router.viewController = view
        return view
    }
}
