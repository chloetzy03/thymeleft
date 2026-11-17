import XCTest
@testable import thyme_left

// MARK: - Chinese food names

@MainActor
final class FoodNameTranslatorTests: XCTestCase {

    private let translator = FoodNameTranslator()

    func test_english_turnsChineseFoodNamesIntoEnglish() async {
        XCTAssertEqual(translator.english(for: "牛奶"), "milk")
        XCTAssertEqual(translator.english(for: "鲜牛奶"), "milk", "describing words like 鲜 are dropped")
        XCTAssertEqual(translator.english(for: "鸡胸肉"), "chicken breast", "the longest word wins over 鸡 + 肉")
        XCTAssertEqual(translator.english(for: "西红柿炒鸡蛋"), "tomato 炒 egg", "known words are swapped, others stay")
        XCTAssertEqual(translator.english(for: "冷冻豌豆"), "frozen peas")
    }

    func test_english_leavesEnglishAndUnknownWordsAlone() async {
        XCTAssertEqual(translator.english(for: "Greek yoghurt"), "Greek yoghurt")
        XCTAssertEqual(translator.english(for: "榴莲"), "榴莲")
        XCTAssertEqual(translator.english(for: "Greek 酸奶"), "Greek yogurt")
    }

    func test_chinese_findsTheChineseWordForARecipeIngredient() async {
        XCTAssertEqual(translator.chinese(forEnglishIngredient: "Cheese"), "奶酪")
        XCTAssertEqual(translator.chinese(forEnglishIngredient: "Eggs"), "鸡蛋", "plurals are understood")
        XCTAssertEqual(translator.chinese(forEnglishIngredient: "Tomatoes"), "西红柿")
        XCTAssertNil(translator.chinese(forEnglishIngredient: "Za'atar"))
    }

    func test_displayName_onlyTranslatesWhenTheAppIsInChinese() async {
        XCTAssertEqual(translator.displayName(forIngredient: "Cheese", languageIsChinese: true), "奶酪")
        XCTAssertEqual(translator.displayName(forIngredient: "Cheese", languageIsChinese: false), "Cheese")
        XCTAssertEqual(translator.displayName(forIngredient: "Za'atar", languageIsChinese: true), "Za'atar")
    }

    func test_everyEntryRoundTripsOrIsADescribingWord() async {
        for entry in FoodNameTranslator.entries where !entry.en.isEmpty && entry.en != "frozen" {
            XCTAssertFalse(translator.english(for: entry.zh).isEmpty, entry.zh)
        }
    }

    func test_joinedForDisplay_usesTheRightComma() async {
        XCTAssertEqual(["Milk", "Eggs"].joinedForDisplay(chinese: false), "Milk, Eggs")
        XCTAssertEqual(["牛奶", "鸡蛋"].joinedForDisplay(chinese: true), "牛奶、鸡蛋")
    }

    func test_matcher_comparesChineseItemsWithEnglishRecipes() async {
        let matcher = IngredientMatcher()
        XCTAssertTrue(matcher.matches(pantryName: "牛奶", recipeIngredient: "Milk"))
        XCTAssertTrue(matcher.matches(pantryName: "鲜牛奶", recipeIngredient: "Milk"))
        XCTAssertTrue(matcher.matches(pantryName: "鸡蛋", recipeIngredient: "Eggs"))
        XCTAssertFalse(matcher.matches(pantryName: "牛奶", recipeIngredient: "Eggs"))
        XCTAssertEqual(matcher.searchKeyword(for: "鸡胸肉", knownIngredients: ["Chicken", "Chicken Breast", "Milk"]),
                       "Chicken Breast")
    }

    func test_emoji_worksForChineseNames() async {
        let provider = EmojiFoodIconProvider()
        XCTAssertEqual(provider.emoji(for: "牛奶"), "🥛")
        XCTAssertEqual(provider.emoji(for: "鸡蛋"), "🥚")
        XCTAssertEqual(provider.emoji(for: "三文鱼"), "🐟")
        XCTAssertEqual(provider.emoji(for: "榴莲"), EmojiFoodIconProvider.fallback)
    }
}

// MARK: - Chinese dates on packs

@MainActor
final class ChineseDateParserTests: XCTestCase {

    private let parser = ExpiryDateParser(calendar: TestCalendar.utc)
    private let now = TestCalendar.date(2026, 11, 15)

    private func parse(_ lines: [String]) -> ScannedExpiryDate? {
        parser.parse(lines: lines, dayFirst: false, now: now)
    }

    func test_chineseDates_inCommonWritingStyles() async {
        let cases: [(String, Date)] = [
            ("保质期至2027年11月5日", TestCalendar.date(2027, 11, 5)),
            ("有效期至 2027年11月5号", TestCalendar.date(2027, 11, 5)),
            ("请在2027年3月8日前食用", TestCalendar.date(2027, 3, 8)),
            ("2027 年 11 月 5 日", TestCalendar.date(2027, 11, 5)),
            ("到期日：27年11月5日", TestCalendar.date(2027, 11, 5)),
            ("２０２７年１１月５日", TestCalendar.date(2027, 11, 5)),
            ("EXP 2027年11月5日", TestCalendar.date(2027, 11, 5))
        ]
        for (text, expected) in cases {
            XCTAssertEqual(parse([text])?.date, expected, text)
        }
    }

    func test_chineseMonthOnly_isEndOfMonth_andFlaggedAsGuessed() async {
        let result = parse(["有效期至2027年11月"])
        XCTAssertEqual(result?.date, TestCalendar.date(2027, 11, 30))
        XCTAssertEqual(result?.dayWasGuessed, true)
    }

    func test_productionDate_isIgnored_whenThereIsAnExpiryDate() async {
        let lines = ["生产日期 2026年9月1日", "保质期至 2027年3月1日"]
        XCTAssertEqual(parse(lines)?.date, TestCalendar.date(2027, 3, 1))
    }

    func test_expiryDateOnTheLineBelowItsLabel_isFound() async {
        XCTAssertEqual(parse(["保质期至", "2027年11月5日"])?.date, TestCalendar.date(2027, 11, 5))
    }

    func test_shelfLifeDurationAlone_isNotADate() async {
        XCTAssertNil(parse(["保质期 12个月"]))
    }
}

// MARK: - Chinese search

@MainActor
final class ChineseSearchTests: XCTestCase {

    private final class OutputSpy: RecipesInteractorOutput {
        var results: [(names: [String], query: String)] = []
        var expectation: XCTestExpectation?
        func didLoad(matches: [RecipeMatch], rescueItemNames: [String], isOffline: Bool) {}
        func didFindNoPantryItems() {}
        func didFindNoRecipes() {}
        func didFail(_ failure: RecipesFailure) {}
        func didLoadSearch(matches: [RecipeMatch], query: String, isOffline: Bool) {
            results.append((matches.map(\.recipe.name), query)); expectation?.fulfill(); expectation = nil
        }
        func didFindNoSearchResults(query: String) {}
        func didFailSearch(_ failure: RecipesFailure) {}
    }

    func test_searchingInChinese_findsEnglishRecipes_andKeepsTheUsersWords() async {
        // Arrange
        let curry = RecipeFixtures.recipe("1", "Chicken Curry", ingredients: ["Chicken", "Curry Powder"])
        let service = StubRecipeService(known: ["Chicken"], recipes: ["1": curry])
        let sut = RecipesInteractor(repository: InMemoryPantryRepository(items: [PantryItem(name: "鸡肉", location: .fridge, expiryDate: Date().addingTimeInterval(86_400 * 3))]),
                                    settingsStore: InMemorySettingsStore(), dateProvider: FixedDateProvider(now: Date()),
                                    service: service, cache: InMemoryRecipeCache())
        let output = OutputSpy()
        sut.output = output
        let done = expectation(description: "reported")
        output.expectation = done

        // Act
        sut.search(query: "鸡肉")
        await fulfillment(of: [done], timeout: 3)

        // Assert: the service was asked in English, but the screen keeps "鸡肉"
        XCTAssertEqual(service.searchedNames, ["chicken"])
        XCTAssertEqual(output.results.first?.names, ["Chicken Curry"])
        XCTAssertEqual(output.results.first?.query, "鸡肉")
    }
}

// MARK: - The translation file itself

@MainActor
final class ChineseTranslationFileTests: XCTestCase {

    /// The app's compiled Chinese strings: key = the English words, value = the Chinese words.
    private func chineseStrings() throws -> [String: String] {
        let appBundle = Bundle(for: RecipesInteractor.self)
        let folder = try XCTUnwrap(appBundle.path(forResource: "zh-Hans", ofType: "lproj"), "zh-Hans is missing from the app")
        let path = folder + "/Localizable.strings"
        let dictionary = try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
        return dictionary
    }

    private func placeholders(in text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: #"%(?:\d+\$)?(lld|lf|@)"#)
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap { Range($0.range(at: 1), in: text).map { String(text[$0]) } }
            .sorted()
    }

    func test_chineseFile_hasTranslationsForTheMainScreens() async throws {
        let strings = try chineseStrings()
        XCTAssertEqual(strings["Home"], "首页")
        XCTAssertEqual(strings["Cancel"], "取消")
        XCTAssertEqual(strings["Add item"], "添加食材")
        XCTAssertGreaterThan(strings.count, 150)
    }

    func test_everyChineseText_isTranslated_andKeepsItsPlaceholders() async throws {
        let strings = try chineseStrings()
        let sameOnPurpose: Set<String> = ["thyme left."]
        for (english, chinese) in strings {
            XCTAssertFalse(chinese.isEmpty, "empty translation for: \(english)")
            if !sameOnPurpose.contains(english) {
                XCTAssertNotEqual(english, chinese, "still English: \(english)")
            }
            XCTAssertEqual(placeholders(in: english), placeholders(in: chinese), "placeholders differ for: \(english)")
        }
    }

    func test_cameraPermissionText_isTranslated() async throws {
        let appBundle = Bundle(for: RecipesInteractor.self)
        let folder = try XCTUnwrap(appBundle.path(forResource: "zh-Hans", ofType: "lproj"))
        let info = try XCTUnwrap(NSDictionary(contentsOfFile: folder + "/InfoPlist.strings") as? [String: String])
        XCTAssertTrue(info["NSCameraUsageDescription"]?.contains("相机") ?? false)
    }
}
