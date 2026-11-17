import XCTest

/// Runs the app in Simplified Chinese: tabs, adding a Chinese-named food, and recipes found for it.
final class ChineseFlowUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingStartOnHome",
                               "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func row(_ text: String) -> XCUIElement {
        app.cells.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    func test_theWholeAppSpeaksChinese() {
        // Assert: the tab bar
        for tab in ["首页", "扫描", "食品柜", "食谱", "我的"] {
            XCTAssertTrue(app.tabBars.buttons[tab].waitForExistence(timeout: 10), "tab \(tab)")
        }
        XCTAssertTrue(app.staticTexts["你的食品柜是空的。添加一些食材，我们来帮你盯着保质期。"].exists)
        attach("1-home-empty")

        // Act: add "牛奶" (milk) expiring tomorrow
        app.tabBars.buttons["食品柜"].tap()
        app.buttons["添加食材"].firstMatch.tap()
        XCTAssertTrue(app.textFields["食材名称"].waitForExistence(timeout: 10))
        app.textFields["食材名称"].tap()
        app.textFields["食材名称"].typeText("牛奶")
        attach("2-form")
        app.buttons["明天"].tap()
        app.buttons["加入食品柜"].tap()

        // Assert: it is in the pantry, with its milk emoji and a Chinese countdown
        XCTAssertTrue(row("牛奶").waitForExistence(timeout: 10))
        XCTAssertTrue(row("牛奶").label.contains("明天到期"), row("牛奶").label)
        attach("3-pantry")

        // Act: recipes are suggested for the Chinese item (the sample recipe source knows "Milk")
        app.tabBars.buttons["食谱"].tap()
        let pudding = row("Milk Pudding")
        XCTAssertTrue(pudding.waitForExistence(timeout: 15), "牛奶 should be understood as milk")
        XCTAssertTrue(pudding.label.contains("还缺：糖") || pudding.label.contains("还缺：Sugar"), pudding.label)
        attach("4-recipes")

        // Act: search in Chinese
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("牛奶")
        XCTAssertTrue(row("Milk Pudding").waitForExistence(timeout: 15))
        attach("5-search")
    }

    func test_settingsAndHomeAreInChinese() {
        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.switches["显示节省的金额"].exists)
        attach("6-settings")
        app.tabBars.buttons["扫描"].tap()
        XCTAssertTrue(app.buttons["选择日期照片"].waitForExistence(timeout: 10))
        attach("7-scan")
    }
}
