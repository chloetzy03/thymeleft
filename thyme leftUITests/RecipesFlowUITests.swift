import XCTest

/// Taps through the Recipes tab. The app uses fixed sample recipes (no internet) in UI tests.
final class RecipesFlowUITests: XCTestCase {

    private var app: XCUIApplication!

    private func launch(extra: [String] = []) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + extra
        app.launch()
    }

    private func addItem(_ name: String) {
        app.buttons["Add item"].firstMatch.tap()
        XCTAssertTrue(app.textFields["Item name"].waitForExistence(timeout: 10))
        app.textFields["Item name"].tap()
        app.textFields["Item name"].typeText(name)
        app.buttons["Add to pantry"].tap()
        XCTAssertTrue(app.cells.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
            .waitForExistence(timeout: 10))
    }

    private func recipeRow(_ name: String) -> XCUIElement {
        app.cells.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
    }

    func test_foodInYourPantry_becomesRecipeSuggestions_andOpensADetailScreen() {
        // Arrange
        launch()
        addItem("Spinach")
        addItem("Eggs")

        // Act
        app.tabBars.buttons["Recipes"].tap()

        // Assert: the list
        let omelette = recipeRow("Spinach Omelette")
        XCTAssertTrue(omelette.waitForExistence(timeout: 15))
        XCTAssertTrue(omelette.label.contains("Uses Eggs, Spinach"), omelette.label) // same expiry, so A to Z
        XCTAssertTrue(omelette.label.contains("Missing: Cheese"), omelette.label)

        // Act: open it
        omelette.tap()

        // Assert: the detail screen (salt is assumed, so 3 of 4)
        XCTAssertTrue(app.staticTexts["You have 3 of 4 ingredients"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Ingredients"].exists)
        XCTAssertTrue(app.staticTexts["Steps"].exists)
        XCTAssertTrue(app.staticTexts["1. Whisk everything together."].exists, "step labels like STEP 1 are dropped")
        XCTAssertTrue(app.buttons["Open the original recipe"].exists)
    }

    func test_aRecipeWithoutASourceLink_hasNoOriginalRecipeButton() {
        // Arrange
        launch()
        addItem("Milk")
        app.tabBars.buttons["Recipes"].tap()

        // Act
        let pudding = recipeRow("Milk Pudding")
        XCTAssertTrue(pudding.waitForExistence(timeout: 15))
        pudding.tap()

        // Assert
        XCTAssertTrue(app.staticTexts["You have 1 of 2 ingredients"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Open the original recipe"].exists)
    }

    func test_switchingToBestMatch_keepsTheRecipesOnScreen() {
        // Arrange
        launch()
        addItem("Spinach")
        app.tabBars.buttons["Recipes"].tap()
        XCTAssertTrue(recipeRow("Spinach Omelette").waitForExistence(timeout: 15))

        // Act
        app.buttons["Best match"].tap()

        // Assert
        XCTAssertTrue(app.buttons["Best match"].isSelected)
        XCTAssertTrue(recipeRow("Spinach Omelette").exists)
    }

    func test_withAnEmptyPantry_asksYouToAddFoodFirst() {
        // Arrange
        launch()

        // Act
        app.tabBars.buttons["Recipes"].tap()

        // Assert
        XCTAssertTrue(app.staticTexts["Add some food first"].waitForExistence(timeout: 15))
    }

    func test_withNoInternetAndNothingSaved_showsAFriendlyOfflineMessage() {
        // Arrange
        launch(extra: ["-uiTestingRecipesOffline"])
        addItem("Milk")

        // Act
        app.tabBars.buttons["Recipes"].tap()

        // Assert
        XCTAssertTrue(app.staticTexts["You're offline"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Try again"].exists)
    }
}
