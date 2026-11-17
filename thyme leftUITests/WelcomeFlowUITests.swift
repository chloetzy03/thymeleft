import XCTest

/// Taps through the first-run welcome tour. UI tests normally skip it; `-uiTestingShowWelcome` brings it back.
final class WelcomeFlowUITests: XCTestCase {

    private var app: XCUIApplication!

    private func launch(showWelcome: Bool = true, extra: [String] = []) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingStartOnHome"] + (showWelcome ? ["-uiTestingShowWelcome"] : []) + extra
        app.launch()
    }

    private var primary: XCUIElement { app.buttons["welcomePrimary"] }
    private var secondary: XCUIElement { app.buttons["welcomeSecondary"] }

    func test_firstLaunch_showsTheTour_andNextWalksThroughIt() {
        launch()

        XCTAssertTrue(app.staticTexts["Scan the date"].waitForExistence(timeout: 10))
        XCTAssertEqual(primary.label, "Next")
        XCTAssertEqual(secondary.label, "Skip")

        primary.tap()
        XCTAssertTrue(app.staticTexts["Swipe when you're done"].waitForExistence(timeout: 5))

        primary.tap()
        XCTAssertTrue(app.staticTexts["We'll remind you"].waitForExistence(timeout: 5))
        XCTAssertEqual(primary.label, "Turn on reminders")
        XCTAssertEqual(secondary.label, "Maybe later")

        primary.tap() // the stub notification centre answers at once
        XCTAssertTrue(app.staticTexts["Good morning, chef!"].waitForExistence(timeout: 10)
                      || app.staticTexts["Good afternoon, chef!"].exists
                      || app.staticTexts["Good evening, chef!"].exists, "Home is behind the tour")
        XCTAssertFalse(primary.exists, "the tour is gone")
    }

    func test_skip_closesTheTourStraightAway() {
        launch()
        XCTAssertTrue(secondary.waitForExistence(timeout: 10))

        secondary.tap()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Scan the date"].exists)
    }

    func test_swipingMovesToTheNextSlide() {
        launch()
        XCTAssertTrue(app.staticTexts["Scan the date"].waitForExistence(timeout: 10))

        app.swipeLeft()

        XCTAssertTrue(app.staticTexts["Swipe when you're done"].waitForExistence(timeout: 5))
        XCTAssertEqual(primary.label, "Next")
    }

    func test_uiTestsNormallySkipTheTour() {
        launch(showWelcome: false)

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["welcomePrimary"].exists)
    }

    func test_settingsCanShowTheTourAgain() {
        launch(showWelcome: false)
        app.tabBars.buttons["Me"].tap()

        let again = app.buttons["Show the welcome tour again"]
        for _ in 0..<4 where !again.isHittable { app.swipeUp() } // it sits at the bottom of Settings
        XCTAssertTrue(again.waitForExistence(timeout: 10))
        again.tap()

        XCTAssertTrue(app.staticTexts["Scan the date"].waitForExistence(timeout: 10))
        secondary.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
    }

    func test_inChinese_theTourIsTranslated() {
        launch(extra: ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"])

        XCTAssertTrue(app.staticTexts["扫描日期"].waitForExistence(timeout: 10))
        XCTAssertEqual(primary.label, "下一步")
        XCTAssertEqual(secondary.label, "跳过")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "welcome-zh"; attachment.lifetime = .keepAlways; add(attachment)
    }

    func test_screenshots_ofEverySlide() {
        launch()
        XCTAssertTrue(app.staticTexts["Scan the date"].waitForExistence(timeout: 10))
        for name in ["slide1", "slide2", "slide3"] {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
            if name != "slide3" { primary.tap(); sleep(1) }
        }
    }
}
