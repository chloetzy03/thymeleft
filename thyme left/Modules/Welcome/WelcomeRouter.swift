import UIKit

/// The host of the Welcome tour: closes it.
@MainActor
final class WelcomeRouter: WelcomeRouterProtocol {

    weak var viewController: UIViewController?

    func close() {
        viewController?.dismiss(animated: true)
    }
}

/// Plugs the five VIPER parts of the Welcome tour together.
@MainActor
enum WelcomeBuilder {

    static func build(store: WelcomeStore, reminders: ReminderServicing) -> UIViewController {
        let view = WelcomeViewController()
        let router = WelcomeRouter()
        let interactor = WelcomeInteractor(store: store, reminders: reminders)
        let presenter = WelcomePresenter(view: view, interactor: interactor, router: router)
        view.presenter = presenter
        interactor.output = presenter
        router.viewController = view
        // Full screen, and not dismissible by dragging: the buttons are the way out.
        view.modalPresentationStyle = .fullScreen
        view.isModalInPresentation = true
        return view
    }
}
