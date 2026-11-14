import Foundation

/// When ONE item should remind you.
/// (Translation: "do what the global setting says", "never remind me about this", or
/// "remind me N days before it expires".)
enum ReminderPreference: Equatable {
    case useDefault
    case never
    case daysBefore(Int)

    /// A single number we can store in the database (databases like simple values).
    /// -2 = use default, -1 = never, 0 or more = that many days before.
    var storedValue: Int {
        switch self {
        case .useDefault: return -2
        case .never: return -1
        case .daysBefore(let days): return max(days, 0)
        }
    }

    init(storedValue: Int) {
        switch storedValue {
        case ...(-2): self = .useDefault
        case -1: self = .never
        default: self = .daysBefore(storedValue)
        }
    }
}
