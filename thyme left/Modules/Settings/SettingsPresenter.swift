import Foundation

/// The manager of the Settings screen: turns settings into labels, and taps into changes.
@MainActor
final class SettingsPresenter: SettingsPresenterProtocol, SettingsInteractorOutput {

    private weak var view: SettingsViewProtocol?
    private let interactor: SettingsInteractorInput
    private let router: SettingsRouterProtocol
    private let dateFormatter: ExpiryDateFormatter
    private let dateProvider: DateProviding
    private let formatter: ExpiryTextFormatter
    private let calendar: Calendar
    private let locale: Locale

    /// The latest settings we were told about. Each change copies these, edits one thing,
    /// and sends the whole bundle back to the Interactor.
    private var settings = AppSettings()
    private var permission: NotificationPermission = .notDetermined

    init(view: SettingsViewProtocol,
         interactor: SettingsInteractorInput,
         router: SettingsRouterProtocol,
         dateFormatter: ExpiryDateFormatter,
         dateProvider: DateProviding,
         formatter: ExpiryTextFormatter = ExpiryTextFormatter(),
         calendar: Calendar = .current,
         locale: Locale = .current) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.dateFormatter = dateFormatter
        self.dateProvider = dateProvider
        self.formatter = formatter
        self.calendar = calendar
        self.locale = locale
    }

    // MARK: Things the View tells us

    func viewDidLoad() { interactor.loadSettings() }
    func viewWillAppear() { interactor.loadSettings() }

    func didChangeNotifications(isOn: Bool) {
        interactor.setNotificationsEnabled(isOn)
    }

    func didSelectDefaultReminder(at index: Int) {
        guard SettingsChoices.reminderDaysBefore.indices.contains(index) else { return }
        change { $0.defaultReminderDaysBefore = SettingsChoices.reminderDaysBefore[index] }
    }

    func didChangeReminderTime(_ time: Date) {
        let parts = calendar.dateComponents([.hour, .minute], from: time)
        change {
            $0.reminderHour = parts.hour ?? $0.reminderHour
            $0.reminderMinute = parts.minute ?? $0.reminderMinute
        }
    }

    func didSelectDateFormat(at index: Int) {
        guard DateFormatPreference.allCases.indices.contains(index) else { return }
        change { $0.dateFormat = DateFormatPreference.allCases[index] }
    }

    func didSelectUrgent(at index: Int) {
        guard SettingsChoices.urgentDays.indices.contains(index) else { return }
        change { $0.urgentDays = SettingsChoices.urgentDays[index] }
    }

    func didSelectSoon(at index: Int) {
        guard SettingsChoices.soonDays.indices.contains(index) else { return }
        change { $0.soonDays = SettingsChoices.soonDays[index] }
    }

    func didChangeShowMoneySaved(isOn: Bool) {
        change { $0.showMoneySaved = isOn }
    }

    func didSelectItemValue(at index: Int) {
        guard SettingsChoices.itemValues.indices.contains(index) else { return }
        change { $0.averageItemValue = SettingsChoices.itemValues[index] }
    }

    func didTapOpenSystemSettings() {
        router.openSystemSettings()
    }

    // MARK: Things the Interactor tells us

    func didLoad(settings: AppSettings, permission: NotificationPermission) {
        self.settings = settings
        self.permission = permission
        view?.showSettings(makeViewModel())
    }

    // MARK: Helpers

    private func change(_ edit: (inout AppSettings) -> Void) {
        var updated = settings
        edit(&updated)
        interactor.save(updated)
    }

    private func makeViewModel() -> SettingsViewModel {
        let reminderDate = calendar.date(bySettingHour: settings.reminderHour, minute: settings.reminderMinute,
                                         second: 0, of: dateProvider.now) ?? dateProvider.now
        let today = dateFormatter.string(from: dateProvider.now, using: settings.dateFormat)

        return SettingsViewModel(
            notificationsEnabled: settings.notificationsEnabled,
            permissionBanner: banner(),
            defaultReminderTitles: SettingsChoices.reminderDaysBefore.map { formatter.reminderLeadText(daysBefore: $0) },
            selectedDefaultReminderIndex: SettingsChoices.reminderDaysBefore.firstIndex(of: settings.defaultReminderDaysBefore) ?? 1,
            reminderTime: reminderDate,
            dateFormatTitles: DateFormatPreference.allCases.map(\.displayName),
            selectedDateFormatIndex: DateFormatPreference.allCases.firstIndex(of: settings.dateFormat) ?? 0,
            datePreview: String(localized: "Today looks like \(today)"),
            urgentTitles: SettingsChoices.urgentDays.map(urgentTitle),
            selectedUrgentIndex: SettingsChoices.urgentDays.firstIndex(of: settings.urgentDays) ?? 1,
            soonTitles: SettingsChoices.soonDays.map { String(localized: "\($0) days or less") },
            selectedSoonIndex: SettingsChoices.soonDays.firstIndex(of: settings.soonDays) ?? 1,
            showMoneySaved: settings.showMoneySaved,
            itemValueTitles: SettingsChoices.itemValues.map { MoneyFormatter.string($0, locale: locale) },
            selectedItemValueIndex: SettingsChoices.itemValues.firstIndex(of: settings.averageItemValue) ?? 2)
    }

    private func urgentTitle(days: Int) -> String {
        switch days {
        case 0: return String(localized: "Expires today")
        case 1: return String(localized: "1 day or less")
        default: return String(localized: "\(days) days or less")
        }
    }

    /// Only shown when the user wants reminders but iOS is blocking them.
    private func banner() -> String? {
        guard settings.notificationsEnabled, permission == .denied else { return nil }
        return String(localized: "Notifications are turned off for thyme left in iOS Settings, so reminders can't reach you.")
    }
}
