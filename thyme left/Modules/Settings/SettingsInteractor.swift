import Foundation

/// The chef of the Settings screen: loads and saves preferences, and keeps reminders in step.
@MainActor
final class SettingsInteractor: SettingsInteractorInput {

    weak var output: SettingsInteractorOutput?

    private let settingsStore: SettingsStore
    private let reminders: ReminderServicing

    init(settingsStore: SettingsStore, reminders: ReminderServicing) {
        self.settingsStore = settingsStore
        self.reminders = reminders
    }

    func loadSettings() {
        emit()
        // Ask iOS what the user currently allows, then show the up-to-date answer.
        Task {
            await reminders.refreshPermission()
            emit()
        }
    }

    func save(_ settings: AppSettings) {
        var cleaned = settings
        // Keep the rules sensible: "amber" can never start before "red" ends.
        cleaned.soonDays = max(cleaned.soonDays, cleaned.urgentDays)
        cleaned.reminderHour = min(max(cleaned.reminderHour, 0), 23)
        cleaned.reminderMinute = min(max(cleaned.reminderMinute, 0), 59)

        settingsStore.save(cleaned)
        reminders.reschedule() // new time / days / on-off must reach the phone
        emit()
    }

    func setNotificationsEnabled(_ isOn: Bool) {
        var settings = settingsStore.load()
        settings.notificationsEnabled = isOn
        // The user is deciding for themselves here, so our one-time explainer isn't needed.
        settings.hasSeenReminderPrimer = true
        settingsStore.save(settings)

        guard isOn, reminders.permission == .notDetermined else {
            reminders.reschedule()
            emit()
            return
        }
        Task {
            _ = await reminders.requestPermission()
            emit()
        }
    }

    private func emit() {
        output?.didLoad(settings: settingsStore.load(), permission: reminders.permission)
    }
}
