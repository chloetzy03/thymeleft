import XCTest

/// Taps through the scanner. The simulator has no live camera, so the app offers
/// "Choose a photo of the date"; the text reader is faked with `-uiTestingScanText`.
final class ScannerFlowUITests: XCTestCase {

    private var app: XCUIApplication!

    private func launch(reading text: String) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingScanText", text]
        app.launch()
    }

    /// Opens the scanner, picks the first picture in the library, and waits for the result card.
    private func pickPictureInScanner() {
        app.buttons["Choose a photo of the date"].tap()
        // Picker items are labelled like "Photo, 15 November, 4:08 PM" (the banner icon is not).
        let firstPicture = app.images.matching(NSPredicate(format: "label BEGINSWITH %@", "Photo")).firstMatch
        XCTAssertTrue(firstPicture.waitForExistence(timeout: 15),
                      "the photo picker should show pictures. Found: \(app.images.allElementsBoundByIndex.map(\.label))")
        // Tap by position: iOS's picker reports its thumbnails as "not hittable" while it animates.
        firstPicture.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    func test_scanTab_opensTheScanner_andAFoundDateFillsTheForm() {
        // Arrange
        launch(reading: "NET WT 500 g|BEST BEFORE 21/11/2026")

        // Act: the Scan tab opens a new item with the scanner running
        app.tabBars.buttons["Scan"].tap()
        XCTAssertTrue(app.buttons["Choose a photo of the date"].waitForExistence(timeout: 10))
        pickPictureInScanner()

        // Assert: the result card
        XCTAssertTrue(app.buttons["Use this date"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Read from: BEST BEFORE 21/11/2026"].exists)

        // Act: accept it
        app.buttons["Use this date"].tap()

        // Assert: back on the form, ready to name the item
        XCTAssertTrue(app.textFields["Item name"].waitForExistence(timeout: 10))
        app.textFields["Item name"].tap()
        app.textFields["Item name"].typeText("Yoghurt")
        app.buttons["Add to pantry"].tap()

        // Assert: it landed in the pantry with the scanned date
        let row = app.cells.matching(NSPredicate(format: "label CONTAINS %@", "Yoghurt")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
    }

    func test_ambiguousDate_offersToSwapDayAndMonth() {
        // Arrange
        launch(reading: "EXP 03/04/2027")

        // Act
        app.buttons["Add item"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Scan date"].waitForExistence(timeout: 10))
        app.buttons["Scan date"].tap()
        pickPictureInScanner()

        // Assert: the other reading is offered
        XCTAssertTrue(app.buttons["Use this date"].waitForExistence(timeout: 10))
        let swap = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Not right?")).firstMatch
        XCTAssertTrue(swap.exists)
        swap.tap()
        XCTAssertTrue(app.buttons["Scan again"].exists)
    }

    func test_pictureWithoutADate_showsAHelpfulMessage() {
        // Arrange
        launch(reading: "Ingredients: oats, water")

        // Act
        app.buttons["Add item"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Scan date"].waitForExistence(timeout: 10))
        app.buttons["Scan date"].tap()
        pickPictureInScanner()

        // Assert
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "We couldn't find a date")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Use this date"].exists)
    }

    func test_cancellingTheScanner_returnsToTheForm() {
        // Arrange
        launch(reading: "EXP 21/11/2026")
        app.buttons["Add item"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Scan date"].waitForExistence(timeout: 10))
        app.buttons["Scan date"].tap()
        XCTAssertTrue(app.buttons["Choose a photo of the date"].waitForExistence(timeout: 10))

        // Act
        app.navigationBars["Scan a date"].buttons["Cancel"].tap() // the form behind has its own Cancel

        // Assert
        XCTAssertTrue(app.textFields["Item name"].waitForExistence(timeout: 10))
    }
}
