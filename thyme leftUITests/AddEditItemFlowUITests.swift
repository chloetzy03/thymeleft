import XCTest

/// Taps through the real app like a user would.
/// (Translation: unit tests check one part in isolation; these check that all the parts
/// work together on screen. They also catch crashes when a screen closes.)
final class AddEditItemFlowUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] // empty, throw-away pantry
        app.launch()
    }

    // MARK: Helpers

    /// Finds a pantry row by part of its spoken description, e.g. "Greek yoghurt".
    private func row(containing text: String) -> XCUIElement {
        app.cells.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func addItem(named name: String) {
        app.buttons["Add item"].firstMatch.tap()
        let nameField = app.textFields["Item name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "The form should open")
        nameField.tap()
        nameField.typeText(name)
        app.buttons["3 days"].tap()
        app.buttons["Add to pantry"].tap()
    }

    // MARK: Tests

    func test_addingAnItem_showsItInTheList() {
        // Arrange: a fresh app shows the empty state
        XCTAssertTrue(app.staticTexts["Nothing here yet"].waitForExistence(timeout: 5))

        // Act
        addItem(named: "Greek yoghurt")

        // Assert
        XCTAssertTrue(row(containing: "Greek yoghurt").waitForExistence(timeout: 5))
        XCTAssertTrue(row(containing: "Greek yoghurt").label.contains("expires in 3 days"))
        XCTAssertFalse(app.textFields["Item name"].exists, "The form should have closed")
    }

    func test_savingWithoutAName_showsAnErrorAndKeepsTheFormOpen() {
        // Arrange
        app.buttons["Add item"].firstMatch.tap()
        XCTAssertTrue(app.textFields["Item name"].waitForExistence(timeout: 5))

        // Act
        app.buttons["Add to pantry"].tap()

        // Assert
        XCTAssertTrue(app.staticTexts["Please give this item a name."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["Item name"].exists)
    }

    func test_cancelling_closesTheFormWithoutAddingAnything() {
        // Arrange
        app.buttons["Add item"].firstMatch.tap()
        XCTAssertTrue(app.textFields["Item name"].waitForExistence(timeout: 5))
        app.textFields["Item name"].tap()
        app.textFields["Item name"].typeText("Ghost item")

        // Act
        app.buttons["Cancel"].tap()

        // Assert
        XCTAssertTrue(app.staticTexts["Nothing here yet"].waitForExistence(timeout: 5))
        XCTAssertFalse(row(containing: "Ghost item").exists)
    }

    func test_editingAnItem_updatesItsName() {
        // Arrange
        addItem(named: "Milk")
        XCTAssertTrue(row(containing: "Milk").waitForExistence(timeout: 5))

        // Act: open the row, replace the name, save
        row(containing: "Milk").tap()
        let nameField = app.textFields["Item name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        XCTAssertEqual(nameField.value as? String, "Milk", "The form should be pre-filled")
        nameField.tap()
        nameField.buttons["Clear text"].tap()
        nameField.typeText("Oat milk")
        app.buttons["Save changes"].tap()

        // Assert
        XCTAssertTrue(row(containing: "Oat milk").waitForExistence(timeout: 5))
        XCTAssertFalse(row(containing: "Milk, ").exists, "The old name should be gone")
    }

    func test_swipingARowLeft_deletesIt() {
        // Arrange
        addItem(named: "Bananas")
        let bananas = row(containing: "Bananas")
        XCTAssertTrue(bananas.waitForExistence(timeout: 5))

        // Act
        bananas.swipeLeft()
        app.buttons["Delete"].tap()

        // Assert
        XCTAssertTrue(app.staticTexts["Nothing here yet"].waitForExistence(timeout: 5))
    }
}
