import XCTest

/// Taps through reminders and settings like a user would.
/// `-uiTestingPermissionUndetermined` pretends iOS has never been asked about notifications,
/// so we can test our friendly "Get reminders?" explainer without a real system pop-up.
final class ReminderAndSettingsUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingPermissionUndetermined"]
        app.launch()
    }

    // MARK: Helpers

    private func row(containing text: String) -> XCUIElement {
        app.cells.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func openForm() {
        app.buttons["Add item"].firstMatch.tap()
        XCTAssertTrue(app.textFields["Item name"].waitForExistence(timeout: 5), "The form should open")
    }

    private func fillAndSave(name: String) {
        app.textFields["Item name"].tap()
        app.textFields["Item name"].typeText(name)
        app.buttons["Add to pantry"].tap()
    }

    // MARK: Reminder explainer

    func test_firstSave_showsTheExplainer_andAllowingClosesTheForm() {
        // Arrange
        openForm()

        // Act
        fillAndSave(name: "Milk")

        // Assert: our friendly explainer appears first
        XCTAssertTrue(app.alerts["Get reminders?"].waitForExistence(timeout: 5))
        app.alerts["Get reminders?"].buttons["Allow reminders"].tap()
        XCTAssertTrue(row(containing: "Milk").waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["Item name"].exists, "The form should close after answering")
    }

    func test_declining_closesTheForm_andWeDoNotAskAgain() {
        // Arrange
        openForm()
        fillAndSave(name: "Milk")
        XCTAssertTrue(app.alerts["Get reminders?"].waitForExistence(timeout: 5))

        // Act
        app.alerts["Get reminders?"].buttons["Not now"].tap()
        XCTAssertTrue(row(containing: "Milk").waitForExistence(timeout: 5))
        openForm()
        fillAndSave(name: "Eggs")

        // Assert: second save goes straight through
        XCTAssertTrue(row(containing: "Eggs").waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts["Get reminders?"].exists)
    }

    func test_reminderChoices_spellOutTheDefault_andNeverSkipsTheExplainer() {
        // Arrange
        openForm()

        // Act + Assert (1): the menu spells out what "default" means right now
        app.buttons["Reminder"].tap()
        XCTAssertTrue(app.buttons["Default (1 day before)"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["1 week before"].exists)

        // Act (2): choose Never and save
        app.buttons["Never"].tap()
        fillAndSave(name: "Salt")

        // Assert (2): no explainer, because no reminder would be sent for this item
        XCTAssertTrue(row(containing: "Salt").waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts["Get reminders?"].exists)
    }

    // MARK: Settings (the Me tab)

    func test_meTab_showsTheSettings_andChangingTheDateFormatUpdatesThePreview() {
        // Arrange
        app.tabBars.buttons["Me"].tap()

        // Assert: the main settings are there
        XCTAssertTrue(app.staticTexts["Expiry reminders"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Turns red"].exists)

        // Act
        app.buttons["Date format"].tap()
        app.buttons["YYYY-MM-DD"].tap()

        // Assert: e.g. "Today looks like 2026-11-15"
        let preview = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "Today looks like \\d{4}-\\d{2}-\\d{2}")).firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
    }

    func test_turningRemindersOff_greysOutTheReminderChoices() {
        // Arrange
        app.tabBars.buttons["Me"].tap()
        let reminderSwitch = app.switches["Reminders"]
        XCTAssertTrue(reminderSwitch.waitForExistence(timeout: 5))

        // Act
        reminderSwitch.tap()

        // Assert
        XCTAssertEqual(reminderSwitch.value as? String, "0")
        XCTAssertFalse(app.buttons["Default reminder"].isEnabled, "the choices should be greyed out")
    }
}
