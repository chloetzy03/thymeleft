import UIKit

/// The host of the Add / Edit screen: knows how to close it.
@MainActor
final class AddEditItemRouter: AddEditItemRouterProtocol {

    weak var viewController: UIViewController?
    private let makeScanner: (_ onResult: @escaping (ScanResult) -> Void) -> UIViewController

    init(makeScanner: @escaping (_ onResult: @escaping (ScanResult) -> Void) -> UIViewController) {
        self.makeScanner = makeScanner
    }

    func showScanner(onResult: @escaping (ScanResult) -> Void) {
        let navigation = UINavigationController(rootViewController: makeScanner(onResult))
        viewController?.present(navigation, animated: true)
    }

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
                      settingsStore: SettingsStore,
                      reminders: ReminderServicing,
                      photoStore: PhotoStoring,
                      dateFormatter: ExpiryDateFormatter,
                      recognizer: TextRecognizing,
                      prefill: ScanResult? = nil,
                      onSaved: @escaping () -> Void) -> UIViewController {
        let view = AddEditItemViewController()
        let router = AddEditItemRouter { onResult in
            ScannerBuilder.build(settingsStore: settingsStore, dateFormatter: dateFormatter,
                                 dateProvider: dateProvider, recognizer: recognizer, onResult: onResult)
        }
        let interactor = AddEditItemInteractor(repository: repository, dateProvider: dateProvider,
                                             settingsStore: settingsStore, reminders: reminders,
                                             photoStore: photoStore)
        let presenter = AddEditItemPresenter(view: view, interactor: interactor, router: router,
                                             iconProvider: iconProvider, dateProvider: dateProvider,
                                             settingsStore: settingsStore, photoStore: photoStore,
                                             existingItem: existing, prefill: prefill,
                                             onSaved: onSaved)
        view.presenter = presenter
        interactor.output = presenter
        router.viewController = view
        return view
    }
}
