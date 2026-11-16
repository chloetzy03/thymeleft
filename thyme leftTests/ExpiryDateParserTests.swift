import XCTest
@testable import thyme_left

final class ExpiryDateParserTests: XCTestCase {

    private let parser = ExpiryDateParser(calendar: TestCalendar.utc)
    /// "Today" for every test: 15 Nov 2026.
    private let now = TestCalendar.date(2026, 11, 15)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        TestCalendar.date(year, month, day)
    }

    private func parse(_ lines: [String], dayFirst: Bool = true) -> ScannedExpiryDate? {
        parser.parse(lines: lines, dayFirst: dayFirst, now: now)
    }

    // MARK: Numeric dates

    func test_parse_numericDates_inManyWritingStyles() {
        // Arrange: (what the camera read, the date we expect)
        let cases: [(String, Date)] = [
            ("EXP 18/11/2026", date(2026, 11, 18)),
            ("EXP: 18/11/2026", date(2026, 11, 18)),
            ("18/11/26", date(2026, 11, 18)),
            ("18.11.2026", date(2026, 11, 18)),
            ("18-11-26", date(2026, 11, 18)),
            ("18 11 2026", date(2026, 11, 18)),
            ("USE BY 5/12/26", date(2026, 12, 5)),
            ("29/02/2028", date(2028, 2, 29))
        ]

        for (text, expected) in cases {
            // Act
            let result = parse([text])

            // Assert
            XCTAssertEqual(result?.date, expected, text)
        }
    }

    func test_parse_yearFirstDates() {
        XCTAssertEqual(parse(["2026-11-18"])?.date, date(2026, 11, 18))
        XCTAssertEqual(parse(["EXP 2026/11/18"])?.date, date(2026, 11, 18))
    }

    // MARK: Month names

    func test_parse_dateswithMonthNames() {
        // Arrange
        let cases: [(String, Date)] = [
            ("BEST BEFORE 18 NOV 2026", date(2026, 11, 18)),
            ("18NOV26", date(2026, 11, 18)),
            ("18 Nov 26", date(2026, 11, 18)),
            ("18 November 2026", date(2026, 11, 18)),
            ("NOV 18 2026", date(2026, 11, 18)),
            ("Nov 18, 2026", date(2026, 11, 18)),
            ("18 SEPT 2027", date(2027, 9, 18)),
            ("EXP 03 JAN 2027", date(2027, 1, 3))
        ]

        for (text, expected) in cases {
            // Act + Assert
            XCTAssertEqual(parse([text])?.date, expected, text)
        }
    }

    func test_parse_monthAndYearOnly_meansTheEndOfThatMonth() {
        let cases: [(String, Date)] = [
            ("EXP 11/2026", date(2026, 11, 30)),
            ("11.26", date(2026, 11, 30)),
            ("NOV 2026", date(2026, 11, 30)),
            ("BB NOV26", date(2026, 11, 30)),
            ("EXP 02/2028", date(2028, 2, 29))   // a leap year
        ]
        for (text, expected) in cases {
            XCTAssertEqual(parse([text])?.date, expected, text)
        }
    }

    // MARK: Day or month first?

    func test_parse_ambiguousDate_followsTheUsersOrderAndOffersTheOtherReading() throws {
        // Act
        let dayFirst = try XCTUnwrap(parse(["03/04/26"], dayFirst: true))
        let monthFirst = try XCTUnwrap(parse(["03/04/26"], dayFirst: false))

        // Assert
        XCTAssertEqual(dayFirst.date, date(2026, 4, 3))
        XCTAssertEqual(dayFirst.alternative, date(2026, 3, 4))
        XCTAssertEqual(monthFirst.date, date(2026, 3, 4))
        XCTAssertEqual(monthFirst.alternative, date(2026, 4, 3))
    }

    func test_parse_unambiguousDates_haveNoAlternative() {
        XCTAssertNil(parse(["13/04/26"])?.alternative, "13 can only be a day")
        XCTAssertNil(parse(["04/13/26"])?.alternative, "13 can only be a day")
        XCTAssertNil(parse(["04/04/26"])?.alternative, "same either way")
        XCTAssertNil(parse(["2026-11-18"])?.alternative)
        XCTAssertNil(parse(["18 NOV 2026"])?.alternative)
    }

    func test_parse_aDayThatCanOnlyBeTheDay_ignoresThePreference() {
        XCTAssertEqual(parse(["11/18/2026"], dayFirst: true)?.date, date(2026, 11, 18))
        XCTAssertEqual(parse(["18/11/2026"], dayFirst: false)?.date, date(2026, 11, 18))
    }

    // MARK: Camera mistakes

    func test_parse_fixesLettersMisreadAsDigits() {
        XCTAssertEqual(parse(["EXP 1O/11/2026"])?.date, date(2026, 11, 10))
        XCTAssertEqual(parse(["EXP 18/11/2O26"])?.date, date(2026, 11, 18))
        XCTAssertEqual(parse(["EXP O5/12/2026"])?.date, date(2026, 12, 5))
        XCTAssertEqual(parse(["EXP I8/11/2026"])?.date, date(2026, 11, 18))
    }

    func test_parse_doesNotBreakMonthNamesThatContainAnO() {
        XCTAssertEqual(parse(["10OCT26"])?.date, date(2026, 10, 10))
        XCTAssertEqual(parse(["18 NOV 2026"])?.date, date(2026, 11, 18))
    }

    // MARK: Choosing between several dates

    func test_parse_prefersTheExpiryDateOverTheManufactureDate_onOneLine() {
        XCTAssertEqual(parse(["MFG 18/05/26 EXP 18/11/26"])?.date, date(2026, 11, 18))
        XCTAssertEqual(parse(["EXP 18/11/26 MFG 18/05/26"])?.date, date(2026, 11, 18))
    }

    func test_parse_prefersTheExpiryDateOverTheManufactureDate_onSeparateLines() {
        XCTAssertEqual(parse(["PROD 18/05/2026", "EXP 18/11/2026"])?.date, date(2026, 11, 18))
        XCTAssertEqual(parse(["EXP 18/11/2026", "PKD 18/05/2026"])?.date, date(2026, 11, 18))
    }

    func test_parse_readsTheLabelFromTheLineAbove() {
        XCTAssertEqual(parse(["BEST BEFORE", "18/11/2026"])?.date, date(2026, 11, 18))
        // ...and a "made on" label above makes the date below it a manufacture date
        XCTAssertNil(parse(["MANUFACTURED ON", "18/05/2026"]))
    }

    func test_parse_aLoneManufactureDate_isNotAnExpiryDate() {
        XCTAssertNil(parse(["MFG 18/05/2026"]))
    }

    func test_parse_withoutLabels_picksTheLaterDate() {
        XCTAssertEqual(parse(["18/05/2026", "18/11/2026"])?.date, date(2026, 11, 18))
    }

    func test_parse_anExpiryLabelBeatsALaterUnlabelledDate() {
        XCTAssertEqual(parse(["EXP 18/11/2026", "12/12/2027"])?.date, date(2026, 11, 18))
    }

    func test_parse_ignoresNoiseAroundTheDate() {
        // Arrange: a realistic pack
        let lines = ["NET WT 500 g", "BATCH L2345 18:45", "Store in a cool dry place", "EXP 18/11/2026", "5 012345 678900"]

        // Act + Assert
        XCTAssertEqual(parse(lines)?.date, date(2026, 11, 18))
    }

    func test_parse_reportsTheLineItCameFrom() {
        XCTAssertEqual(parse(["NET WT 500 g", "  EXP 18/11/2026  "])?.sourceText, "EXP 18/11/2026")
    }

    // MARK: Things that are not usable dates

    func test_parse_rejectsImpossibleDates() {
        XCTAssertNil(parse(["31/02/2026"]))
        XCTAssertNil(parse(["29/02/2027"]))
        XCTAssertNil(parse(["99/99/99"]))
        XCTAssertNil(parse(["EXP 00/11/2026"]))
    }

    func test_parse_rejectsDatesTooFarAwayToBeReal() {
        XCTAssertNil(parse(["18/11/2010"]), "years ago")
        XCTAssertNil(parse(["18/11/2099"]), "decades ahead")
    }

    func test_parse_acceptsRecentlyExpiredDates() {
        XCTAssertEqual(parse(["EXP 01/11/2026"])?.date, date(2026, 11, 1))
    }

    func test_parse_withNoDateAtAll_returnsNil() {
        XCTAssertNil(parse([]))
        XCTAssertNil(parse(["", "  "]))
        XCTAssertNil(parse(["NET WT 500 g", "Ingredients: milk, sugar", "MAY CONTAIN NUTS"]))
    }
}

final class DayFirstPreferenceTests: XCTestCase {

    func test_isDayFirst_followsTheChosenFormat() {
        XCTAssertTrue(DateFormatPreference.dayMonthYear.isDayFirst())
        XCTAssertFalse(DateFormatPreference.monthDayYear.isDayFirst())
        XCTAssertTrue(DateFormatPreference.yearMonthDay.isDayFirst())
    }

    func test_isDayFirst_matchMyPhone_looksAtTheRegion() {
        XCTAssertTrue(DateFormatPreference.system.isDayFirst(locale: Locale(identifier: "en_GB")))
        XCTAssertTrue(DateFormatPreference.system.isDayFirst(locale: Locale(identifier: "en_SG")))
        XCTAssertFalse(DateFormatPreference.system.isDayFirst(locale: Locale(identifier: "en_US")))
    }
}
