import Testing
import Foundation
@testable import thyme_left

struct ExpiryPolicyTests {

    private let policy = ExpiryPolicy(urgentDays: 1, soonDays: 5)
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }
    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    @Test func sameDayIsZeroDaysEvenIfLaterInTheDay() {
        let days = policy.daysRemaining(until: date(15, hour: 23), from: date(15, hour: 1), calendar: calendar)
        #expect(days == 0)
    }

    @Test func tomorrowMorningIsOneDay() {
        let days = policy.daysRemaining(until: date(16, hour: 8), from: date(15, hour: 22), calendar: calendar)
        #expect(days == 1)
    }

    @Test func pastDatesAreNegative() {
        let days = policy.daysRemaining(until: date(13), from: date(15), calendar: calendar)
        #expect(days == -2)
    }

    @Test(arguments: [
        (-1, ExpiryStatus.expired),
        (0, .urgent), (1, .urgent),
        (2, .soon), (5, .soon),
        (6, .fresh), (120, .fresh)
    ])
    func statusBoundaries(days: Int, expected: ExpiryStatus) {
        #expect(policy.status(forDaysRemaining: days) == expected)
    }

    @Test func customThresholdsAreRespected() {
        let strict = ExpiryPolicy(urgentDays: 2, soonDays: 7)
        #expect(strict.status(forDaysRemaining: 2) == .urgent)
        #expect(strict.status(forDaysRemaining: 7) == .soon)
        #expect(strict.status(forDaysRemaining: 8) == .fresh)
    }
}
