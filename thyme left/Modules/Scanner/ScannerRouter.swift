import UIKit

/// The host of the Scanner screen: hands the result back and closes.
@MainActor
final class ScannerRouter: ScannerRouterProtocol {

    weak var viewController: UIViewController?
    private let onResult: (ScanResult) -> Void

    init(onResult: @escaping (ScanResult) -> Void) {
        self.onResult = onResult
    }

    func finish(with result: ScanResult) {
        // Close first, then hand over the result, so the form below is visible when it updates.
        viewController?.dismiss(animated: true) { [onResult] in onResult(result) }
    }

    func close() {
        viewController?.dismiss(animated: true)
    }
}

/// Plugs the five VIPER parts of the Scanner screen together.
@MainActor
enum ScannerBuilder {

    static func build(settingsStore: SettingsStore,
                      dateFormatter: ExpiryDateFormatter,
                      dateProvider: DateProviding,
                      recognizer: TextRecognizing,
                      onResult: @escaping (ScanResult) -> Void) -> UIViewController {
        let view = ScannerViewController()
        let router = ScannerRouter(onResult: onResult)
        let interactor = ScannerInteractor(recognizer: recognizer, settingsStore: settingsStore,
                                           dateProvider: dateProvider)
        let presenter = ScannerPresenter(view: view, interactor: interactor, router: router,
                                         dateFormatter: dateFormatter, dateProvider: dateProvider,
                                         policy: { settingsStore.load().expiryPolicy })
        view.presenter = presenter
        interactor.output = presenter
        router.viewController = view
        return view
    }
}
