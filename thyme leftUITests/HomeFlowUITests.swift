import XCTest

/// Taps through the Home tab and the swipe choices (Used it / Threw away / Delete).
final class HomeFlowUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingStartOnHome"]
        app.launch()
    }

    // MARK: Helpers

    /// Adds an item that expires TOMORROW (so Home lists it as "use soon").
    private func addItemExpiringTomorrow(_ name: String) {
        app.tabBars.buttons["Pantry"].tap()
        app.buttons["Add item"].firstMatch.tap()
        XCTAssertTrue(app.textFields["Item name"].waitForExistence(timeout: 10))
        app.textFields["Item name"].tap()
        app.textFields["Item name"].typeText(name)
        app.buttons["Tomorrow"].tap()
        app.buttons["Add to pantry"].tap()
        XCTAssertTrue(row(name).waitForExistence(timeout: 10))
    }

    private func row(_ name: String) -> XCUIElement {
        app.cells.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
    }

    private func swipeAndChoose(_ name: String, _ action: String) {
        row(name).swipeLeft()
        XCTAssertTrue(app.buttons[action].waitForExistence(timeout: 5))
        app.buttons[action].tap()
    }

    private func staticText(beginningWith text: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", text)).firstMatch
    }

    // MARK: Tests

    func test_homeIsTheFirstTab_withATimeAwareGreeting() {
        XCTAssertTrue(app.staticTexts["thyme left."].waitForExistence(timeout: 10))
        let greeting = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "Good (morning|afternoon|evening), chef!")).firstMatch
        XCTAssertTrue(greeting.exists)
    }

    func test_emptyPantry_offersToAddTheFirstItem() {
        // Assert
        XCTAssertTrue(app.staticTexts["Your pantry is empty. Add something and we'll watch the dates."]
            .waitForExistence(timeout: 10))

        // Act
        app.buttons["Add your first item"].tap()

        // Assert: it takes you to the Pantry
        XCTAssertTrue(app.buttons["Add item"].firstMatch.waitForExistence(timeout: 10))
    }

    func test_foodAboutToExpire_appearsAsATileOnHome() {
        // Arrange
        addItemExpiringTomorrow("Milk")

        // Act
        app.tabBars.buttons["Home"].tap()

        // Assert
        XCTAssertTrue(app.staticTexts["You've got 1 ingredient to use soon."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Milk, expires tomorrow"].exists, "the tile is a tappable button")
    }

    func test_whatCanICook_opensTheRecipesTab() {
        // Act
        app.buttons["What can I cook?"].tap()

        // Assert: with an empty pantry, Recipes asks you to add food first
        XCTAssertTrue(app.staticTexts["Add some food first"].waitForExistence(timeout: 15))
    }

    func test_swipingUsedIt_removesTheItem_andCountsItAsSaved() {
        // Arrange
        addItemExpiringTomorrow("Milk")

        // Act
        swipeAndChoose("Milk", "Used it")
        XCTAssertTrue(app.staticTexts["Nothing here yet"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Home"].tap()

        // Assert
        XCTAssertTrue(staticText(beginningWith: "1 item used up this month").waitForExistence(timeout: 10))
    }

    func test_threwAway_andDelete_doNotCountAsSaved() {
        // Arrange
        addItemExpiringTomorrow("Milk")
        addItemExpiringTomorrow("Bread")

        // Act
        swipeAndChoose("Milk", "Threw away")
        swipeAndChoose("Bread", "Delete")
        app.tabBars.buttons["Home"].tap()

        // Assert: nothing was "used", so the counter still invites you to mark food as used
        XCTAssertTrue(staticText(beginningWith: "Swipe a pantry item and tap").waitForExistence(timeout: 10))
    }

    func test_aLongSwipe_doesNotDeleteAnything() {
        // Arrange
        addItemExpiringTomorrow("Milk")

        // Act: a very long swipe should only reveal the buttons
        let milk = row("Milk")
        milk.swipeLeft(velocity: .fast)

        // Assert
        XCTAssertTrue(app.buttons["Used it"].waitForExistence(timeout: 5), "the choices are shown")
        XCTAssertTrue(milk.exists, "and the item is still there")
    }

    func test_meTab_hasTheSavingsSettings() {
        // Act
        app.tabBars.buttons["Me"].tap()

        // Assert
        XCTAssertTrue(app.switches["Show money saved"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Average item value"].exists)
    }
}
