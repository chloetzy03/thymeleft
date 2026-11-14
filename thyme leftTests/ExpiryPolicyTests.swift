import XCTest
@testable import thyme_left

final class ExpiryPolicyTests: XCTestCase {

    // MARK: Helpers

    private let policy = ExpiryPolicy(urgentDays: 1, soonDays: 5)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    // MARK: daysRemaining

    func test_daysRemaining_sameDayLaterInTheDay_isZero() {
        // Arrange
        let now = date(day: 15, hour: 1)
        let expiry = date(day: 15, hour: 23)

        // Act
        let days = policy.daysRemaining(until: expiry, from: now, calendar: calendar)

        // Assert
        XCTAssertEqual(days, 0)
    }

    func test_daysRemaining_tomorrowMorning_isOne() {
        // Arrange
        let now = date(day: 15, hour: 22)
        let expiry = date(day: 16, hour: 8)

        // Act
        let days = policy.daysRemaining(until: expiry, from: now, calendar: calendar)

        // Assert
        XCTAssertEqual(days, 1)
    }

    func test_daysRemaining_dateInThePast_isNegative() {
        // Arrange
        let now = date(day: 15)
        let expiry = date(day: 13)

        // Act
        let days = policy.daysRemaining(until: expiry, from: now, calendar: calendar)

        // Assert
        XCTAssertEqual(days, -2)
    }

    // MARK: status

    func test_status_atEachBoundary_returnsExpectedStatus() {
        // Arrange: (days left, the status we expect)
        let cases: [(days: Int, expected: ExpiryStatus)] = [
            (-1, .expired),
            (0, .urgent), (1, .urgent),
            (2, .soon), (5, .soon),
            (6, .fresh), (120, .fresh)
        ]

        for testCase in cases {
            // Act
            let status = policy.status(forDaysRemaining: testCase.days)

            // Assert
            XCTAssertEqual(status, testCase.expected, "\(testCase.days) days left")
        }
    }

    func test_status_withCustomThresholds_respectsThem() {
        // Arrange
        let strict = ExpiryPolicy(urgentDays: 2, soonDays: 7)

        // Act
        let atTwo = strict.status(forDaysRemaining: 2)
        let atSeven = strict.status(forDaysRemaining: 7)
        let atEight = strict.status(forDaysRemaining: 8)

        // Assert
        XCTAssertEqual(atTwo, .urgent)
        XCTAssertEqual(atSeven, .soon)
        XCTAssertEqual(atEight, .fresh)
    }
}
