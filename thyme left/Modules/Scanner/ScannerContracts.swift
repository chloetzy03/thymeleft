import Foundation

// The "who may ask whom" rulebook for the Scanner screen.

/// What the "we found a date" card shows.
struct ScanFoundViewModel: Equatable {
    let dateText: String        // "18 Nov 2026"
    let countdownText: String   // "Expires in 3 days"
    let sourceText: String      // the line we read: "EXP 18/11/26"
    /// Set when day and month could be swapped, e.g. "Read as 3 Apr? Tap for 4 Mar".
    let swapText: String?
    /// Set when the pack showed no day, e.g. "No day found, so we used the last day of the month."
    var guessNote: String? = nil
}

// MARK: - View (the waiter)

@MainActor
protocol ScannerViewProtocol: AnyObject {
    func showSearching()
    func showFound(_ found: ScanFoundViewModel)
    func showNothingFound(message: String)
}

// MARK: - Presenter (the manager)

@MainActor
protocol ScannerPresenterProtocol: AnyObject {
    func viewDidLoad()
    /// Text lines the live camera can currently see.
    func didSeeLines(_ lines: [String])
    func didPickImage(_ data: Data)
    func didTapSwap()
    func didTapRetry()
    /// `photoData` is a picture of the pack when the user chose to keep one.
    func didConfirm(photoData: Data?)
    func didTapCancel()
}

// MARK: - Interactor (the chef)

@MainActor
protocol ScannerInteractorInput: AnyObject {
    func considerLiveLines(_ lines: [String])
    func readImage(_ data: Data)
    func resetLiveReading()
}

@MainActor
protocol ScannerInteractorOutput: AnyObject {
    func didFind(_ found: ScannedExpiryDate)
    func didFindNothing()
}

// MARK: - Router (the host)

@MainActor
protocol ScannerRouterProtocol: AnyObject {
    func finish(with result: ScanResult)
    func close()
}
