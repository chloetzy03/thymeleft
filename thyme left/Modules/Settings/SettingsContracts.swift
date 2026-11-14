import Foundation

// The "who may ask whom" rulebook for the Settings (Me) screen.

/// Everything the Settings screen needs to draw itself.
struct SettingsViewModel: Equatable {
    let notificationsEnabled: Bool
    /// Not nil when iOS is blocking our notifications (we then show a banner).
    let permissionBanner: String?

    let defaultReminderTitles: [String]
    let selectedDefaultReminderIndex: Int
    let reminderTime: Date

    let dateFormatTitles: [String]
    let selectedDateFormatIndex: Int
    let datePreview: String

    let urgentTitles: [String]
    let selectedUrgentIndex: Int
    let soonTitles: [String]
    let selectedSoonIndex: Int
}

// MARK: - View (the waiter)

@MainActor
protocol SettingsViewProtocol: AnyObject {
    func showSettings(_ settings: SettingsViewModel)
}

// MARK: - Presenter (the manager)

@MainActor
protocol SettingsPresenterProtocol: AnyObject {
    func viewDidLoad()
    func viewWillAppear()
    func didChangeNotifications(isOn: Bool)
    func didSelectDefaultReminder(at index: Int)
    func didChangeReminderTime(_ time: Date)
    func didSelectDateFormat(at index: Int)
    func didSelectUrgent(at index: Int)
    func didSelectSoon(at index: Int)
    func didTapOpenSystemSettings()
}

// MARK: - Interactor (the chef)

@MainActor
protocol SettingsInteractorInput: AnyObject {
    func loadSettings()
    func save(_ settings: AppSettings)
    func setNotificationsEnabled(_ isOn: Bool)
}

@MainActor
protocol SettingsInteractorOutput: AnyObject {
    func didLoad(settings: AppSettings, permission: NotificationPermission)
}

// MARK: - Router (the host)

@MainActor
protocol SettingsRouterProtocol: AnyObject {
    func openSystemSettings()
}
