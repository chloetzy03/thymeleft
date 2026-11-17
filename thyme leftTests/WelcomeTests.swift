import XCTest
@testable import thyme_left

// MARK: - Welcome presenter

@MainActor
final class WelcomePresenterTests: XCTestCase {

    private final class ViewSpy: WelcomeViewProtocol {
        var slides: [WelcomeSlideViewModel] = []
        var pages: [(page: WelcomePageViewModel, animated: Bool)] = []
        func showSlides(_ slides: [WelcomeSlideViewModel]) { self.slides = slides }
        func showPage(_ page: WelcomePageViewModel, animated: Bool) { pages.append((page, animated)) }
    }

    private final class InteractorSpy: WelcomeInteractorInput {
        var finishCalls: [Bool] = []
        func finish(askForReminders: Bool) { finishCalls.append(askForReminders) }
    }

    private final class RouterSpy: WelcomeRouterProtocol {
        var closeCount = 0
        func close() { closeCount += 1 }
    }

    private func makeSUT() -> (sut: WelcomePresenter, view: ViewSpy, interactor: InteractorSpy, router: RouterSpy) {
        let view = ViewSpy(), interactor = InteractorSpy(), router = RouterSpy()
        let sut = WelcomePresenter(view: view, interactor: interactor, router: router)
        sut.viewDidLoad()
        return (sut, view, interactor, router)
    }

    func test_viewDidLoad_showsThreeSlides_andTheFirstPage() async throws {
        let (_, view, _, _) = makeSUT()

        XCTAssertEqual(view.slides.map(\.title), ["Scan the date", "Swipe when you're done", "We'll remind you"])
        let first = try XCTUnwrap(view.pages.first)
        XCTAssertEqual(first.page, WelcomePageViewModel(index: 0, count: 3, primaryTitle: "Next",
                                                        secondaryTitle: "Skip", pageAccessibilityText: "Page 1 of 3"))
        XCTAssertFalse(first.animated, "the first page just appears")
    }

    func test_next_movesThroughTheSlides_andTheLastOneOffersReminders() async throws {
        let (sut, view, interactor, _) = makeSUT()

        sut.didTapPrimary()
        XCTAssertEqual(view.pages.last?.page.index, 1)
        XCTAssertEqual(view.pages.last?.page.primaryTitle, "Next")
        XCTAssertEqual(view.pages.last?.animated, true)

        sut.didTapPrimary()
        let last = try XCTUnwrap(view.pages.last?.page)
        XCTAssertEqual(last.index, 2)
        XCTAssertEqual(last.primaryTitle, "Turn on reminders")
        XCTAssertEqual(last.secondaryTitle, "Maybe later")
        XCTAssertEqual(last.pageAccessibilityText, "Page 3 of 3")
        XCTAssertTrue(interactor.finishCalls.isEmpty, "nothing is finished until the last button")
    }

    func test_primaryOnTheLastSlide_finishesAndAsksForReminders() async {
        let (sut, _, interactor, _) = makeSUT()
        sut.didChangePage(to: 2)

        sut.didTapPrimary()

        XCTAssertEqual(interactor.finishCalls, [true])
    }

    func test_skip_andMaybeLater_finishWithoutAsking() async {
        let first = makeSUT()
        first.sut.didTapSecondary()
        XCTAssertEqual(first.interactor.finishCalls, [false])

        let last = makeSUT()
        last.sut.didChangePage(to: 2)
        last.sut.didTapSecondary()
        XCTAssertEqual(last.interactor.finishCalls, [false])
    }

    func test_swipingToAnotherSlide_updatesThePage_andIgnoresNonsense() async {
        let (sut, view, _, _) = makeSUT()
        let shown = view.pages.count

        sut.didChangePage(to: 1)
        XCTAssertEqual(view.pages.last?.page.index, 1)

        sut.didChangePage(to: 1) // same slide again
        sut.didChangePage(to: 7) // doesn't exist
        sut.didChangePage(to: -1)
        XCTAssertEqual(view.pages.count, shown + 1, "only the real change was shown")
    }

    func test_whenFinished_theTourCloses() async {
        let (sut, _, _, router) = makeSUT()

        sut.didFinish()

        XCTAssertEqual(router.closeCount, 1)
    }
}

// MARK: - Welcome interactor

@MainActor
final class WelcomeInteractorTests: XCTestCase {

    private final class OutputSpy: WelcomeInteractorOutput {
        var finishCount = 0
        var expectation: XCTestExpectation?
        func didFinish() { finishCount += 1; expectation?.fulfill(); expectation = nil }
    }

    private func makeSUT() -> (sut: WelcomeInteractor, store: InMemoryWelcomeStore, reminders: ReminderServiceSpy, output: OutputSpy) {
        let store = InMemoryWelcomeStore()
        let reminders = ReminderServiceSpy(permission: .notDetermined)
        let sut = WelcomeInteractor(store: store, reminders: reminders)
        let output = OutputSpy()
        sut.output = output
        return (sut, store, reminders, output)
    }

    func test_finishWithoutAsking_remembersTheTour_andNeverTouchesReminders() async {
        let (sut, store, reminders, output) = makeSUT()

        sut.finish(askForReminders: false)

        XCTAssertTrue(store.hasSeenWelcome)
        XCTAssertEqual(reminders.requestCount, 0)
        XCTAssertEqual(output.finishCount, 1)
    }

    func test_finishAndAsk_remembersTheTour_asksIOS_thenPlansReminders() async {
        let (sut, store, reminders, output) = makeSUT()
        let done = expectation(description: "finished")
        output.expectation = done

        sut.finish(askForReminders: true)
        XCTAssertTrue(store.hasSeenWelcome, "remembered straight away, before the iOS question is answered")
        await fulfillment(of: [done], timeout: 3)

        XCTAssertEqual(reminders.requestCount, 1)
        XCTAssertEqual(reminders.rescheduleCount, 1)
        XCTAssertEqual(output.finishCount, 1)
    }

    func test_finishAndAsk_carriesOn_evenWhenTheUserSaysNo() async {
        let (sut, _, reminders, output) = makeSUT()
        reminders.permissionAfterRequest = .denied
        let done = expectation(description: "finished")
        output.expectation = done

        sut.finish(askForReminders: true)
        await fulfillment(of: [done], timeout: 3)

        XCTAssertEqual(output.finishCount, 1)
    }
}

// MARK: - Remembering, the settings link and the UI-test switch

@MainActor
final class WelcomeStoreAndWiringTests: XCTestCase {

    func test_inMemoryStore_startsUnseen_thenRemembers() async {
        let store = InMemoryWelcomeStore()
        XCTAssertFalse(store.hasSeenWelcome)

        store.markWelcomeSeen()

        XCTAssertTrue(store.hasSeenWelcome)
    }

    func test_userDefaultsStore_remembersAcrossInstances() async throws {
        let suite = "welcome-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertFalse(UserDefaultsWelcomeStore(defaults: defaults).hasSeenWelcome)

        UserDefaultsWelcomeStore(defaults: defaults).markWelcomeSeen()

        XCTAssertTrue(UserDefaultsWelcomeStore(defaults: defaults).hasSeenWelcome, "a new instance (like after relaunch) still knows")
    }

    func test_uiTestsSkipTheTour_unlessAskedToShowIt() async {
        XCTAssertTrue(AppContainer(arguments: ["-uiTesting"]).welcomeStore.hasSeenWelcome)
        XCTAssertFalse(AppContainer(arguments: ["-uiTesting", "-uiTestingShowWelcome"]).welcomeStore.hasSeenWelcome)
    }
}
