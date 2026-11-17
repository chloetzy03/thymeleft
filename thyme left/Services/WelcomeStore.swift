import Foundation

/// A "job description" for remembering whether the welcome tour has been shown.
/// (Translation: a tiny yes/no memory, "has this person seen the intro?")
@MainActor
protocol WelcomeStore: AnyObject {
    var hasSeenWelcome: Bool { get }
    func markWelcomeSeen()
}

/// Remembers the answer on the phone using UserDefaults.
@MainActor
final class UserDefaultsWelcomeStore: WelcomeStore {

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "hasSeenWelcome.v1") {
        self.defaults = defaults
        self.key = key
    }

    var hasSeenWelcome: Bool { defaults.bool(forKey: key) }
    func markWelcomeSeen() { defaults.set(true, forKey: key) }
}

/// Remembers the answer in memory only. Used by tests and UI tests.
@MainActor
final class InMemoryWelcomeStore: WelcomeStore {

    private(set) var hasSeenWelcome: Bool

    init(hasSeenWelcome: Bool = false) {
        self.hasSeenWelcome = hasSeenWelcome
    }

    func markWelcomeSeen() { hasSeenWelcome = true }
}
