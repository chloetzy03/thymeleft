import Foundation

/// A "job description" for anything that can remember the user's settings.
/// (Translation: today we save them in UserDefaults; later we could sync them with iCloud
/// without changing any screen.)
@MainActor
protocol SettingsStore: AnyObject {
    func load() -> AppSettings
    func save(_ settings: AppSettings)
}

/// Saves settings on the phone using UserDefaults (a small built-in notebook for preferences).
@MainActor
final class UserDefaultsSettingsStore: SettingsStore {

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "appSettings.v1") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> AppSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings() // first launch, or unreadable data: use the defaults
        }
        return settings
    }

    func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}

/// Keeps settings in memory only. Used by tests and UI tests.
@MainActor
final class InMemorySettingsStore: SettingsStore {

    private var settings: AppSettings

    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
    }

    func load() -> AppSettings { settings }
    func save(_ settings: AppSettings) { self.settings = settings }
}
