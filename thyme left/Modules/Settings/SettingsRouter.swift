import UIKit

/// The host of the Settings screen.
@MainActor
final class SettingsRouter: SettingsRouterProtocol {

    func openSystemSettings() {
        // Jumps to this app's page in the iPhone's Settings app.
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

/// Plugs the five VIPER parts of the Settings screen together.
@MainActor
enum SettingsBuilder {

    static func build(settingsStore: SettingsStore,
                      reminders: ReminderServicing,
                      dateFormatter: ExpiryDateFormatter,
                      dateProvider: DateProviding) -> UIViewController {
        let view = SettingsViewController()
        let router = SettingsRouter()
        let interactor = SettingsInteractor(settingsStore: settingsStore, reminders: reminders)
        let presenter = SettingsPresenter(view: view, interactor: interactor, router: router,
                                          dateFormatter: dateFormatter, dateProvider: dateProvider)
        view.presenter = presenter
        interactor.output = presenter
        return view
    }
}
