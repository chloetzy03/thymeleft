import UIKit

/// The host of the Scanner screen: hands the result back and closes.
@MainActor
final class ScannerRouter: ScannerRouterProtocol {

    weak var viewController: UIViewController?
    private let onResult: (ScanResult) -> Void
    private let isPopUp: Bool

    /// `isPopUp` is true when the scanner was opened on top of another screen (from the Add form).
    /// The Scan tab is not a pop-up, so there is nothing to close there.
    init(isPopUp: Bool, onResult: @escaping (ScanResult) -> Void) {
        self.isPopUp = isPopUp
        self.onResult = onResult
    }

    func finish(with result: ScanResult) {
        guard isPopUp else { onResult(result); return }
        // Close first, then hand over the result, so the form below is visible when it updates.
        viewController?.dismiss(animated: true) { [onResult] in onResult(result) }
    }

    func close() {
        guard isPopUp else { return }
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
                      isPopUp: Bool = true,
                      onResult: @escaping (ScanResult) -> Void) -> UIViewController {
        let view = ScannerViewController(isPopUp: isPopUp)
        let router = ScannerRouter(isPopUp: isPopUp, onResult: onResult)
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
