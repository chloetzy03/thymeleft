import UIKit

/// Builds the Add / Edit screen. (Translation: the Router is handed a "recipe" for making that
/// screen, so it never needs to know about databases or clocks.)
typealias AddEditItemFactory = (_ existing: PantryItem?, _ onSaved: @escaping () -> Void) -> UIViewController

/// The host of the Pantry screen: knows how to move to other screens.
/// (Translation: the Presenter says "go to Add Item"; the Router knows how to actually do it.)
@MainActor
final class PantryListRouter: PantryListRouterProtocol {

    /// Weak so the Router doesn't keep the screen alive after it has been closed.
    weak var viewController: UIViewController?
    private let makeAddEditItem: AddEditItemFactory

    init(makeAddEditItem: @escaping AddEditItemFactory) {
        self.makeAddEditItem = makeAddEditItem
    }

    func showAddItem(onSaved: @escaping () -> Void) {
        present(makeAddEditItem(nil, onSaved))
    }

    func showEditItem(_ item: PantryItem, onSaved: @escaping () -> Void) {
        present(makeAddEditItem(item, onSaved))
    }

    /// Slides the form up from the bottom, with its own top bar (Cancel / Save).
    private func present(_ screen: UIViewController) {
        let navigation = UINavigationController(rootViewController: screen)
        viewController?.present(navigation, animated: true)
    }
}

/// Plugs the five VIPER parts together. (Translation: the "assembly line" that builds the
/// screen and introduces each part to its neighbours. Nobody else needs to know how.)
@MainActor
enum PantryListBuilder {

    static func build(repository: PantryRepository,
                      settingsStore: SettingsStore,
                      dateProvider: DateProviding,
                      iconProvider: FoodIconProviding,
                      dateFormatter: ExpiryDateFormatter,
                      reminders: ReminderServicing) -> UIViewController {
        let view = PantryListViewController()
        let router = PantryListRouter { existing, onSaved in
            AddEditItemBuilder.build(existing: existing, repository: repository,
                                     dateProvider: dateProvider, iconProvider: iconProvider,
                                     settingsStore: settingsStore, reminders: reminders,
                                     onSaved: onSaved)
        }
        let interactor = PantryListInteractor(repository: repository, settingsStore: settingsStore,
                                           dateProvider: dateProvider, reminders: reminders)
        let presenter = PantryListPresenter(view: view, interactor: interactor, router: router,
                                          iconProvider: iconProvider, dateFormatter: dateFormatter)

        view.presenter = presenter
        interactor.output = presenter
        router.viewController = view
        return view
    }
}
