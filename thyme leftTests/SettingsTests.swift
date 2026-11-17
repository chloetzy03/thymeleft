import XCTest
@testable import thyme_left

// MARK: - Storing settings

@MainActor
final class SettingsStoreTests: XCTestCase {

    /// A private, throw-away UserDefaults so tests never touch the real app's settings.
    private func makeDefaults() -> UserDefaults {
        let name = "thyme-left-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    func test_load_whenNothingSavedYet_returnsDefaults() async {
        // Arrange
        let store = UserDefaultsSettingsStore(defaults: makeDefaults())

        // Act
        let settings = store.load()

        // Assert
        XCTAssertEqual(settings, AppSettings())
        XCTAssertTrue(settings.notificationsEnabled)
        XCTAssertEqual(settings.defaultReminderDaysBefore, 1)
        XCTAssertEqual(settings.reminderHour, 9)
    }

    func test_save_thenLoad_returnsWhatWasSaved() async {
        // Arrange
        let store = UserDefaultsSettingsStore(defaults: makeDefaults())
        var changed = AppSettings()
        changed.dateFormat = .yearMonthDay
        changed.reminderHour = 18
        changed.urgentDays = 2

        // Act
        store.save(changed)

        // Assert
        XCTAssertEqual(store.load(), changed)
    }

    func test_load_withCorruptData_fallsBackToDefaults() async {
        // Arrange
        let defaults = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: "appSettings.v1")
        let store = UserDefaultsSettingsStore(defaults: defaults)

        // Act + Assert
        XCTAssertEqual(store.load(), AppSettings())
    }

    func test_load_withSettingsFromAnOlderVersion_keepsWhatExistsAndDefaultsTheRest() async throws {
        // Arrange: an old save that only knew about two fields
        let defaults = makeDefaults()
        defaults.set(Data(#"{"reminderHour": 20, "dateFormat": "monthDayYear"}"#.utf8), forKey: "appSettings.v1")
        let store = UserDefaultsSettingsStore(defaults: defaults)

        // Act
        let settings = store.load()

        // Assert
        XCTAssertEqual(settings.reminderHour, 20)
        XCTAssertEqual(settings.dateFormat, .monthDayYear)
        XCTAssertEqual(settings.soonDays, 5) // newer field gets its default
        XCTAssertTrue(settings.notificationsEnabled)
    }

    func test_expiryPolicy_isBuiltFromTheThresholds() async {
        // Arrange
        var settings = AppSettings()
        settings.urgentDays = 2
        settings.soonDays = 7

        // Act + Assert
        XCTAssertEqual(settings.expiryPolicy, ExpiryPolicy(urgentDays: 2, soonDays: 7))
    }
}

// MARK: - Small value types

final class ReminderPreferenceTests: XCTestCase {

    func test_storedValue_roundTripsEveryKind() async {
        // Arrange
        let all: [ReminderPreference] = [.useDefault, .never, .daysBefore(0), .daysBefore(1), .daysBefore(7)]

        for preference in all {
            // Act
            let restored = ReminderPreference(storedValue: preference.storedValue)

            // Assert
            XCTAssertEqual(restored, preference)
        }
    }

    func test_storedValue_usesTheAgreedNumbers() async {
        XCTAssertEqual(ReminderPreference.useDefault.storedValue, -2)
        XCTAssertEqual(ReminderPreference.never.storedValue, -1)
        XCTAssertEqual(ReminderPreference.daysBefore(3).storedValue, 3)
    }
}

@MainActor
final class ExpiryDateFormatterTests: XCTestCase {

    private let date = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 12))!

    func test_string_followsTheChosenFormat() async {
        // Arrange
        let cases: [(DateFormatPreference, String)] = [
            (.dayMonthYear, "08/11/2026"),
            (.monthDayYear, "11/08/2026"),
            (.yearMonthDay, "2026-11-08")
        ]

        for (preference, expected) in cases {
            var settings = AppSettings()
            settings.dateFormat = preference
            let formatter = ExpiryDateFormatter(settingsStore: InMemorySettingsStore(settings: settings))

            // Act
            let text = formatter.string(from: date)

            // Assert
            XCTAssertEqual(text, expected, preference.displayName)
        }
    }

    func test_string_changesWhenTheSettingChanges() async {
        // Arrange
        let store = InMemorySettingsStore()
        let formatter = ExpiryDateFormatter(settingsStore: store)
        var settings = AppSettings()
        settings.dateFormat = .dayMonthYear
        store.save(settings)
        let before = formatter.string(from: date)

        // Act
        settings.dateFormat = .yearMonthDay
        store.save(settings)
        let after = formatter.string(from: date)

        // Assert
        XCTAssertEqual(before, "08/11/2026")
        XCTAssertEqual(after, "2026-11-08")
    }

    func test_string_matchMyPhone_usesTheLocalesStyle() async {
        // Arrange
        let formatter = ExpiryDateFormatter(settingsStore: InMemorySettingsStore(),
                                            locale: Locale(identifier: "en_GB"))

        // Act
        let text = formatter.string(from: date)

        // Assert
        XCTAssertEqual(text, "8 Nov 2026")
    }
}

final class ReminderLeadTextTests: XCTestCase {

    func test_reminderLeadText_readsNaturally() async {
        // Arrange
        let formatter = ExpiryTextFormatter()
        let cases: [(Int, String)] = [(0, "Same day"), (1, "1 day before"), (2, "2 days before"),
                                      (3, "3 days before"), (7, "1 week before")]

        for (days, expected) in cases {
            // Act + Assert
            XCTAssertEqual(formatter.reminderLeadText(daysBefore: days), expected)
        }
    }
}

// MARK: - Settings screen: Interactor

@MainActor
final class SettingsInteractorTests: XCTestCase {

    private final class OutputSpy: SettingsInteractorOutput {
        var loads: [(settings: AppSettings, permission: NotificationPermission)] = []
        var expectation: XCTestExpectation?

        func didLoad(settings: AppSettings, permission: NotificationPermission) {
            loads.append((settings, permission))
            expectation?.fulfill()
        }
    }

    private func makeSUT(settings: AppSettings = AppSettings(), permission: NotificationPermission = .authorized)
        -> (sut: SettingsInteractor, output: OutputSpy, store: InMemorySettingsStore, reminders: ReminderServiceSpy) {
        let store = InMemorySettingsStore(settings: settings)
        let reminders = ReminderServiceSpy(permission: permission)
        let sut = SettingsInteractor(settingsStore: store, reminders: reminders)
        let output = OutputSpy()
        sut.output = output
        return (sut, output, store, reminders)
    }

    func test_loadSettings_reportsTheStoredSettingsThenRefreshesPermission() async {
        // Arrange
        var stored = AppSettings()
        stored.reminderHour = 20
        let (sut, output, _, reminders) = makeSUT(settings: stored)
        output.expectation = expectation(description: "reported twice")
        output.expectation?.expectedFulfillmentCount = 2

        // Act
        sut.loadSettings()
        await fulfillment(of: [output.expectation!], timeout: 2)

        // Assert
        XCTAssertEqual(output.loads.first?.settings.reminderHour, 20)
        XCTAssertEqual(reminders.refreshCount, 1)
    }

    func test_save_storesTheSettingsReplansRemindersAndReports() async {
        // Arrange
        let (sut, output, store, reminders) = makeSUT()
        var changed = AppSettings()
        changed.defaultReminderDaysBefore = 3

        // Act
        sut.save(changed)

        // Assert
        XCTAssertEqual(store.load().defaultReminderDaysBefore, 3)
        XCTAssertEqual(reminders.rescheduleCount, 1)
        XCTAssertEqual(output.loads.last?.settings.defaultReminderDaysBefore, 3)
    }

    func test_save_keepsAmberFromStartingBeforeRedEnds() async {
        // Arrange
        let (sut, _, store, _) = makeSUT()
        var impossible = AppSettings()
        impossible.urgentDays = 3
        impossible.soonDays = 1

        // Act
        sut.save(impossible)

        // Assert
        XCTAssertEqual(store.load().soonDays, 3)
    }

    func test_save_keepsTheReminderTimeValid() async {
        // Arrange
        let (sut, _, store, _) = makeSUT()
        var silly = AppSettings()
        silly.reminderHour = 99
        silly.reminderMinute = -5

        // Act
        sut.save(silly)

        // Assert
        XCTAssertEqual(store.load().reminderHour, 23)
        XCTAssertEqual(store.load().reminderMinute, 0)
    }

    func test_setNotificationsEnabled_firstTime_asksIOSForPermission() async {
        // Arrange
        var off = AppSettings()
        off.notificationsEnabled = false
        let (sut, output, store, reminders) = makeSUT(settings: off, permission: .notDetermined)
        output.expectation = expectation(description: "reported after the request")

        // Act
        sut.setNotificationsEnabled(true)
        await fulfillment(of: [output.expectation!], timeout: 2)

        // Assert
        XCTAssertTrue(store.load().notificationsEnabled)
        XCTAssertEqual(reminders.requestCount, 1)
        XCTAssertEqual(output.loads.last?.permission, .authorized)
    }

    func test_setNotificationsEnabled_whenAlreadyDecided_doesNotAskAgain() async {
        // Arrange
        let (sut, _, store, reminders) = makeSUT(permission: .denied)

        // Act
        sut.setNotificationsEnabled(true)

        // Assert
        XCTAssertEqual(reminders.requestCount, 0)
        XCTAssertEqual(reminders.rescheduleCount, 1)
        XCTAssertTrue(store.load().notificationsEnabled)
    }

    func test_setNotificationsEnabled_false_savesAndClearsReminders() async {
        // Arrange
        let (sut, _, store, reminders) = makeSUT()

        // Act
        sut.setNotificationsEnabled(false)

        // Assert
        XCTAssertFalse(store.load().notificationsEnabled)
        XCTAssertEqual(reminders.rescheduleCount, 1)
    }
}

// MARK: - Settings screen: Presenter

@MainActor
final class SettingsPresenterTests: XCTestCase {

    private final class ViewSpy: SettingsViewProtocol {
        var model: SettingsViewModel?
        func showSettings(_ settings: SettingsViewModel) { model = settings }
    }

    private final class InteractorSpy: SettingsInteractorInput {
        var loadCount = 0
        var saved: [AppSettings] = []
        var notificationsRequests: [Bool] = []

        func loadSettings() { loadCount += 1 }
        func save(_ settings: AppSettings) { saved.append(settings) }
        func setNotificationsEnabled(_ isOn: Bool) { notificationsRequests.append(isOn) }
    }

    private final class RouterSpy: SettingsRouterProtocol {
        var openCount = 0, welcomeCount = 0
        func openSystemSettings() { openCount += 1 }
        func showWelcome() { welcomeCount += 1 }
    }

    private let calendar = TestCalendar.utc
    private let now = TestCalendar.date(2026, 11, 15, hour: 12) // midday, so the date is the same in every time zone

    private func makeSUT(settings: AppSettings = AppSettings(), permission: NotificationPermission = .authorized)
        -> (sut: SettingsPresenter, view: ViewSpy, interactor: InteractorSpy, router: RouterSpy) {
        let view = ViewSpy(), interactor = InteractorSpy(), router = RouterSpy()
        let formatter = ExpiryDateFormatter(settingsStore: InMemorySettingsStore(settings: settings),
                                            locale: Locale(identifier: "en_GB"))
        let sut = SettingsPresenter(view: view, interactor: interactor, router: router,
                                    dateFormatter: formatter, dateProvider: FixedDateProvider(now: now),
                                    calendar: calendar)
        sut.didLoad(settings: settings, permission: permission) // the screen has been given its settings
        return (sut, view, interactor, router)
    }

    func test_viewDidLoadAndWillAppear_askTheInteractorToLoad() async {
        let (sut, _, interactor, _) = makeSUT()
        sut.viewDidLoad()
        sut.viewWillAppear()
        XCTAssertEqual(interactor.loadCount, 2)
    }

    func test_didLoad_describesTheSettingsInWords() async throws {
        // Arrange
        var settings = AppSettings()
        settings.defaultReminderDaysBefore = 2
        settings.dateFormat = .yearMonthDay
        settings.reminderHour = 18
        settings.reminderMinute = 30

        // Act
        let (_, view, _, _) = makeSUT(settings: settings)

        // Assert
        let model = try XCTUnwrap(view.model)
        XCTAssertTrue(model.notificationsEnabled)
        XCTAssertEqual(model.defaultReminderTitles, ["Same day", "1 day before", "2 days before", "3 days before", "1 week before"])
        XCTAssertEqual(model.selectedDefaultReminderIndex, 2)
        XCTAssertEqual(model.reminderTime, TestCalendar.date(2026, 11, 15, hour: 18, minute: 30))
        XCTAssertEqual(model.dateFormatTitles, ["Match my phone", "DD/MM/YYYY", "MM/DD/YYYY", "YYYY-MM-DD"])
        XCTAssertEqual(model.selectedDateFormatIndex, 3)
        XCTAssertEqual(model.datePreview, "Today looks like 2026-11-15")
        XCTAssertEqual(model.urgentTitles, ["Expires today", "1 day or less", "2 days or less", "3 days or less"])
        XCTAssertEqual(model.soonTitles, ["3 days or less", "5 days or less", "7 days or less", "10 days or less"])
    }

    func test_banner_appearsOnlyWhenRemindersAreWantedButBlocked() async {
        // Arrange
        var off = AppSettings()
        off.notificationsEnabled = false

        // Act
        let blocked = makeSUT(permission: .denied)
        let allowed = makeSUT(permission: .authorized)
        let switchedOff = makeSUT(settings: off, permission: .denied)

        // Assert
        XCTAssertNotNil(blocked.view.model?.permissionBanner)
        XCTAssertNil(allowed.view.model?.permissionBanner)
        XCTAssertNil(switchedOff.view.model?.permissionBanner)
    }

    func test_choosingAnOption_sendsTheWholeUpdatedSettingsBack() async {
        // Arrange
        let (sut, _, interactor, _) = makeSUT()

        // Act
        sut.didSelectDefaultReminder(at: 3)  // 3 days before
        sut.didSelectDateFormat(at: 2)       // MM/DD/YYYY
        sut.didSelectUrgent(at: 2)           // 2 days or less
        sut.didSelectSoon(at: 2)             // 7 days or less

        // Assert: each change started from the latest settings and edited one thing
        XCTAssertEqual(interactor.saved.map(\.defaultReminderDaysBefore), [3, 1, 1, 1])
        XCTAssertEqual(interactor.saved[1].dateFormat, .monthDayYear)
        XCTAssertEqual(interactor.saved[2].urgentDays, 2)
        XCTAssertEqual(interactor.saved[3].soonDays, 7)
    }

    func test_changingTheTime_savesHourAndMinute() async {
        // Arrange
        let (sut, _, interactor, _) = makeSUT()

        // Act
        sut.didChangeReminderTime(TestCalendar.date(2026, 1, 1, hour: 7, minute: 45))

        // Assert
        XCTAssertEqual(interactor.saved.last?.reminderHour, 7)
        XCTAssertEqual(interactor.saved.last?.reminderMinute, 45)
    }

    func test_invalidChoices_areIgnored() async {
        // Arrange
        let (sut, _, interactor, _) = makeSUT()

        // Act
        sut.didSelectDefaultReminder(at: 99)
        sut.didSelectDateFormat(at: -1)
        sut.didSelectUrgent(at: 42)
        sut.didSelectSoon(at: 42)

        // Assert
        XCTAssertTrue(interactor.saved.isEmpty)
    }

    func test_togglingNotifications_goesToTheInteractor() async {
        // Arrange
        let (sut, _, interactor, _) = makeSUT()

        // Act
        sut.didChangeNotifications(isOn: false)
        sut.didChangeNotifications(isOn: true)

        // Assert
        XCTAssertEqual(interactor.notificationsRequests, [false, true])
    }

    func test_tappingOpenSettings_asksTheRouter() async {
        // Arrange
        let (sut, _, _, router) = makeSUT()

        // Act
        sut.didTapOpenSystemSettings()

        // Assert
        XCTAssertEqual(router.openCount, 1)
    }

    func test_tappingShowWelcomeAgain_asksTheRouter() async {
        // Arrange
        let (sut, _, _, router) = makeSUT()

        // Act
        sut.didTapShowWelcome()

        // Assert
        XCTAssertEqual(router.welcomeCount, 1)
    }
}
