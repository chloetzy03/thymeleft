import XCTest
@testable import thyme_left

// MARK: - Scanner Interactor

@MainActor
final class ScannerInteractorTests: XCTestCase {

    private final class OutputSpy: ScannerInteractorOutput {
        var found: [ScannedExpiryDate] = []
        var nothingCount = 0
        var expectation: XCTestExpectation?

        func didFind(_ found: ScannedExpiryDate) { self.found.append(found); expectation?.fulfill() }
        func didFindNothing() { nothingCount += 1; expectation?.fulfill() }
    }

    /// A pretend text reader that returns whatever lines we give it.
    private final class RecognizerStub: TextRecognizing {
        var lines: [String] = []
        var error: Error?
        func recognizeLines(in imageData: Data) async throws -> [String] {
            if let error { throw error }
            return lines
        }
    }

    private let now = TestCalendar.date(2026, 11, 15)

    private func makeSUT(dateFormat: DateFormatPreference = .dayMonthYear)
        -> (sut: ScannerInteractor, output: OutputSpy, recognizer: RecognizerStub) {
        var settings = AppSettings()
        settings.dateFormat = dateFormat
        let recognizer = RecognizerStub()
        let sut = ScannerInteractor(parser: ExpiryDateParser(calendar: TestCalendar.utc),
                                    recognizer: recognizer,
                                    settingsStore: InMemorySettingsStore(settings: settings),
                                    dateProvider: FixedDateProvider(now: now),
                                    locale: Locale(identifier: "en_GB"))
        let output = OutputSpy()
        sut.output = output
        return (sut, output, recognizer)
    }

    func test_liveLines_areTrustedOnlyAfterTheSameDateIsSeenRepeatedly() async {
        // Arrange
        let (sut, output, _) = makeSUT()
        let lines = ["NET WT 500 g", "EXP 18/11/2026"]

        // Act
        sut.considerLiveLines(lines)
        let afterFirst = output.found.count
        sut.considerLiveLines(lines)

        // Assert
        XCTAssertEqual(afterFirst, 0, "one sighting could be a flicker")
        XCTAssertEqual(output.found.count, 1)
        XCTAssertEqual(output.found.first?.date, TestCalendar.date(2026, 11, 18))
    }

    func test_liveLines_aDifferentDateRestartsTheCount() async {
        // Arrange
        let (sut, output, _) = makeSUT()

        // Act: the camera flips between two readings, never the same twice in a row
        sut.considerLiveLines(["EXP 18/11/2026"])
        sut.considerLiveLines(["EXP 19/11/2026"])
        sut.considerLiveLines(["EXP 18/11/2026"])

        // Assert
        XCTAssertTrue(output.found.isEmpty)
    }

    func test_liveLines_withoutADate_reportNothing() async {
        let (sut, output, _) = makeSUT()
        sut.considerLiveLines(["NET WT 500 g"])
        sut.considerLiveLines(["NET WT 500 g"])
        XCTAssertTrue(output.found.isEmpty)
    }

    func test_liveLines_afterReporting_stayQuietUntilReset() async {
        // Arrange
        let (sut, output, _) = makeSUT()
        let lines = ["EXP 18/11/2026"]
        sut.considerLiveLines(lines)
        sut.considerLiveLines(lines)

        // Act: the camera keeps seeing the same pack
        sut.considerLiveLines(lines)
        sut.considerLiveLines(lines)
        let beforeReset = output.found.count
        sut.resetLiveReading()
        sut.considerLiveLines(lines)
        sut.considerLiveLines(lines)

        // Assert
        XCTAssertEqual(beforeReset, 1)
        XCTAssertEqual(output.found.count, 2)
    }

    func test_liveLines_followTheUsersDayOrder() async {
        // Arrange
        let dayFirst = makeSUT(dateFormat: .dayMonthYear)
        let monthFirst = makeSUT(dateFormat: .monthDayYear)

        // Act
        for made in [dayFirst, monthFirst] {
            made.sut.considerLiveLines(["EXP 03/04/26"])
            made.sut.considerLiveLines(["EXP 03/04/26"])
        }

        // Assert
        XCTAssertEqual(dayFirst.output.found.first?.date, TestCalendar.date(2026, 4, 3))
        XCTAssertEqual(monthFirst.output.found.first?.date, TestCalendar.date(2026, 3, 4))
    }

    func test_readImage_reportsTheDateImmediately() async {
        // Arrange
        let (sut, output, recognizer) = makeSUT()
        recognizer.lines = ["BEST BEFORE 18 NOV 2026"]
        output.expectation = expectation(description: "reported")

        // Act
        sut.readImage(Data([1]))
        await fulfillment(of: [output.expectation!], timeout: 2)

        // Assert
        XCTAssertEqual(output.found.first?.date, TestCalendar.date(2026, 11, 18))
    }

    func test_readImage_whenNoDateIsFound_saysSo() async {
        // Arrange
        let (sut, output, recognizer) = makeSUT()
        recognizer.lines = ["Ingredients: milk"]
        output.expectation = expectation(description: "reported")

        // Act
        sut.readImage(Data([1]))
        await fulfillment(of: [output.expectation!], timeout: 2)

        // Assert
        XCTAssertEqual(output.nothingCount, 1)
    }

    func test_readImage_whenTheReaderFails_saysNothingWasFound() async {
        // Arrange
        let (sut, output, recognizer) = makeSUT()
        recognizer.error = TextRecognitionError.unreadableImage
        output.expectation = expectation(description: "reported")

        // Act
        sut.readImage(Data([1]))
        await fulfillment(of: [output.expectation!], timeout: 2)

        // Assert
        XCTAssertEqual(output.nothingCount, 1)
    }
}

// MARK: - Scanner Presenter

@MainActor
final class ScannerPresenterTests: XCTestCase {

    private final class ViewSpy: ScannerViewProtocol {
        var searchingCount = 0
        var found: [ScanFoundViewModel] = []
        var nothingMessage: String?

        func showSearching() { searchingCount += 1 }
        func showFound(_ found: ScanFoundViewModel) { self.found.append(found) }
        func showNothingFound(message: String) { nothingMessage = message }
    }

    private final class InteractorSpy: ScannerInteractorInput {
        var liveLines: [[String]] = []
        var images: [Data] = []
        var resetCount = 0

        func considerLiveLines(_ lines: [String]) { liveLines.append(lines) }
        func readImage(_ data: Data) { images.append(data) }
        func resetLiveReading() { resetCount += 1 }
    }

    private final class RouterSpy: ScannerRouterProtocol {
        var results: [ScanResult] = []
        var closeCount = 0
        func finish(with result: ScanResult) { results.append(result) }
        func close() { closeCount += 1 }
    }

    private let now = TestCalendar.date(2026, 11, 15, hour: 12)

    private func makeSUT() -> (sut: ScannerPresenter, view: ViewSpy, interactor: InteractorSpy, router: RouterSpy) {
        var settings = AppSettings()
        settings.dateFormat = .dayMonthYear
        let view = ViewSpy(), interactor = InteractorSpy(), router = RouterSpy()
        let formatter = ExpiryDateFormatter(settingsStore: InMemorySettingsStore(settings: settings))
        let sut = ScannerPresenter(view: view, interactor: interactor, router: router,
                                   dateFormatter: formatter, dateProvider: FixedDateProvider(now: now),
                                   calendar: TestCalendar.utc)
        return (sut, view, interactor, router)
    }

    private func found(_ day: Int, month: Int = 11, alternative: Date? = nil) -> ScannedExpiryDate {
        ScannedExpiryDate(date: TestCalendar.date(2026, month, day), sourceText: "EXP \(day)/\(month)/26", alternative: alternative)
    }

    func test_viewDidLoad_showsTheSearchingState() async {
        let (sut, view, _, _) = makeSUT()
        sut.viewDidLoad()
        XCTAssertEqual(view.searchingCount, 1)
    }

    func test_liveLines_goToTheInteractor_untilAResultIsShowing() async {
        // Arrange
        let (sut, _, interactor, _) = makeSUT()
        sut.didSeeLines(["a"])

        // Act
        sut.didFind(found(18))
        sut.didSeeLines(["b"]) // ignored: a result is already on the card

        // Assert
        XCTAssertEqual(interactor.liveLines, [["a"]])
    }

    func test_pickedImages_goToTheInteractor() async {
        let (sut, _, interactor, _) = makeSUT()
        sut.didPickImage(Data([7]))
        XCTAssertEqual(interactor.images, [Data([7])])
    }

    func test_didFind_showsTheDateCountdownAndSource() async throws {
        // Arrange
        let (sut, view, _, _) = makeSUT()

        // Act
        sut.didFind(found(18))

        // Assert
        let card = try XCTUnwrap(view.found.first)
        XCTAssertEqual(card.dateText, "18/11/2026")
        XCTAssertEqual(card.countdownText, "Expires in 3 days")
        XCTAssertEqual(card.sourceText, "EXP 18/11/26")
        XCTAssertNil(card.swapText)
    }

    func test_didFind_countdownWordsForTodayTomorrowAndPast() async {
        // Arrange
        let (sut, view, _, _) = makeSUT()

        // Act
        sut.didFind(found(15)); sut.didFind(found(16)); sut.didFind(found(10))

        // Assert
        XCTAssertEqual(view.found.map(\.countdownText),
                       ["Expires today", "Expires tomorrow", "That date has already passed"])
    }

    func test_swapping_togglesBetweenTheTwoReadings_andConfirmUsesTheShownOne() async throws {
        // Arrange
        let (sut, view, _, router) = makeSUT()
        let april3 = TestCalendar.date(2026, 4, 3)
        let march4 = TestCalendar.date(2026, 3, 4)
        sut.didFind(ScannedExpiryDate(date: april3, sourceText: "03/04/26", alternative: march4))
        XCTAssertNotNil(view.found.last?.swapText)

        // Act
        sut.didTapSwap()
        sut.didConfirm(photoData: nil)

        // Assert
        XCTAssertEqual(view.found.last?.dateText, "04/03/2026")
        XCTAssertEqual(router.results, [ScanResult(date: march4, photoData: nil)])

        // Act: swap back
        sut.didTapSwap()
        sut.didConfirm(photoData: nil)
        XCTAssertEqual(router.results.last?.date, april3)
    }

    func test_swapping_withNoAlternative_doesNothing() async {
        // Arrange
        let (sut, view, _, _) = makeSUT()
        sut.didFind(found(18))

        // Act
        sut.didTapSwap()

        // Assert
        XCTAssertEqual(view.found.count, 1)
    }

    func test_confirm_passesTheDateAndPhotoToTheRouter() async {
        // Arrange
        let (sut, _, _, router) = makeSUT()
        sut.didFind(found(18))

        // Act
        sut.didConfirm(photoData: Data([1, 2]))

        // Assert
        XCTAssertEqual(router.results, [ScanResult(date: TestCalendar.date(2026, 11, 18), photoData: Data([1, 2]))])
    }

    func test_confirm_withNothingFound_doesNothing() async {
        let (sut, _, _, router) = makeSUT()
        sut.didConfirm(photoData: nil)
        XCTAssertTrue(router.results.isEmpty)
    }

    func test_retry_clearsTheResultAndRestartsReading() async {
        // Arrange
        let (sut, view, interactor, _) = makeSUT()
        sut.didFind(found(18))

        // Act
        sut.didTapRetry()
        sut.didSeeLines(["EXP 19/11/26"]) // lines are accepted again

        // Assert
        XCTAssertEqual(interactor.resetCount, 1)
        XCTAssertEqual(view.searchingCount, 1)
        XCTAssertEqual(interactor.liveLines.count, 1)
    }

    func test_nothingFound_showsAHelpfulMessage() async {
        let (sut, view, _, _) = makeSUT()
        sut.didFindNothing()
        XCTAssertNotNil(view.nothingMessage)
    }

    func test_cancel_closesTheScanner() async {
        let (sut, _, _, router) = makeSUT()
        sut.didTapCancel()
        XCTAssertEqual(router.closeCount, 1)
    }
}
