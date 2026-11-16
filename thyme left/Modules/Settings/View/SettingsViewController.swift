import UIKit

/// The waiter of the Settings screen: shows the toggles and menus, reports changes.
final class SettingsViewController: UIViewController, SettingsViewProtocol {

    var presenter: SettingsPresenterProtocol?

    private let notificationsSwitch = UISwitch()
    private let defaultReminderButton = UIButton(type: .system)
    private let reminderTimePicker = UIDatePicker()
    private let dateFormatButton = UIButton(type: .system)
    private let datePreviewLabel = UILabel()
    private let urgentButton = UIButton(type: .system)
    private let soonButton = UIButton(type: .system)
    private let moneySwitch = UISwitch()
    private let itemValueButton = UIButton(type: .system)
    private let bannerCard = UIView()
    private var bannerRow = UIView() // the banner plus its margins; hidden as one piece
    private let bannerLabel = UILabel()

    private var reminderRows: [UIView] = []
    private let savingsNote = UILabel()

    // MARK: Life of the screen

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Colors.background
        navigationItem.title = "Settings" // not `title`: that would also rename the tab
        navigationController?.navigationBar.prefersLargeTitles = true
        buildLayout()
        presenter?.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter?.viewWillAppear() // the user may have changed iOS Settings while away
    }

    // MARK: SettingsViewProtocol

    func showSettings(_ settings: SettingsViewModel) {
        notificationsSwitch.setOn(settings.notificationsEnabled, animated: false)

        bannerLabel.text = settings.permissionBanner
        bannerRow.isHidden = (settings.permissionBanner == nil)

        configureMenu(defaultReminderButton, titles: settings.defaultReminderTitles,
                      selected: settings.selectedDefaultReminderIndex) { [weak self] in
            self?.presenter?.didSelectDefaultReminder(at: $0)
        }
        reminderTimePicker.setDate(settings.reminderTime, animated: false)

        configureMenu(dateFormatButton, titles: settings.dateFormatTitles,
                      selected: settings.selectedDateFormatIndex) { [weak self] in
            self?.presenter?.didSelectDateFormat(at: $0)
        }
        datePreviewLabel.text = settings.datePreview

        configureMenu(urgentButton, titles: settings.urgentTitles,
                      selected: settings.selectedUrgentIndex) { [weak self] in
            self?.presenter?.didSelectUrgent(at: $0)
        }
        configureMenu(soonButton, titles: settings.soonTitles,
                      selected: settings.selectedSoonIndex) { [weak self] in
            self?.presenter?.didSelectSoon(at: $0)
        }

        moneySwitch.setOn(settings.showMoneySaved, animated: false)
        configureMenu(itemValueButton, titles: settings.itemValueTitles,
                      selected: settings.selectedItemValueIndex) { [weak self] in
            self?.presenter?.didSelectItemValue(at: $0)
        }
        itemValueButton.isEnabled = settings.showMoneySaved
        itemValueButton.superview?.superview?.alpha = settings.showMoneySaved ? 1 : 0.4

        // Grey out the reminder choices while notifications are off. Disabling the controls
        // (not just dimming them) also tells VoiceOver they are unavailable.
        defaultReminderButton.isEnabled = settings.notificationsEnabled
        reminderTimePicker.isEnabled = settings.notificationsEnabled
        reminderRows.forEach { $0.alpha = settings.notificationsEnabled ? 1 : 0.4 }
    }

    // MARK: Building the screen

    /// Turns a button into a pop-up menu of choices.
    private func configureMenu(_ button: UIButton, titles: [String], selected: Int,
                               onSelect: @escaping (Int) -> Void) {
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = Theme.Colors.brand
        button.configuration = config
        button.menu = UIMenu(children: titles.enumerated().map { index, title in
            UIAction(title: title, state: index == selected ? .on : .off) { _ in onSelect(index) }
        })
        button.showsMenuAsPrimaryAction = true
        button.changesSelectionAsPrimaryAction = true
    }

    private func sectionHeader(_ text: String) -> UIView {
        let label = UILabel()
        label.text = text
        label.font = Theme.Typography.caption.font
        label.textColor = Theme.Colors.muted
        label.adjustsFontForContentSizeCategory = true
        label.accessibilityTraits = .header
        return pad(label, top: 12, bottom: 0)
    }

    /// Adds the standard 16 pt side margins around a view.
    private func pad(_ inner: UIView, top: CGFloat = 0, bottom: CGFloat = 0) -> UIView {
        let wrapper = UIView()
        inner.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: top),
            inner.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -bottom),
            inner.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 20),
            inner.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -20)
        ])
        return wrapper
    }

    private func card(_ row: FormCardRow) -> UIView {
        let wrapper = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: wrapper.topAnchor),
            row.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            row.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -16)
        ])
        return wrapper
    }

    private func buildLayout() {
        // Controls
        notificationsSwitch.onTintColor = Theme.Colors.brand
        notificationsSwitch.accessibilityLabel = "Reminders"
        notificationsSwitch.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.presenter?.didChangeNotifications(isOn: self.notificationsSwitch.isOn)
        }, for: .valueChanged)

        reminderTimePicker.datePickerMode = .time
        reminderTimePicker.preferredDatePickerStyle = .compact
        reminderTimePicker.tintColor = Theme.Colors.brand
        reminderTimePicker.accessibilityLabel = "Reminder time"
        reminderTimePicker.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.presenter?.didChangeReminderTime(self.reminderTimePicker.date)
        }, for: .valueChanged)

        moneySwitch.onTintColor = Theme.Colors.brand
        moneySwitch.accessibilityLabel = "Show money saved"
        moneySwitch.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.presenter?.didChangeShowMoneySaved(isOn: self.moneySwitch.isOn)
        }, for: .valueChanged)
        itemValueButton.accessibilityLabel = "Average item value"

        defaultReminderButton.accessibilityLabel = "Default reminder"
        dateFormatButton.accessibilityLabel = "Date format"
        urgentButton.accessibilityLabel = "Red when"
        soonButton.accessibilityLabel = "Amber when"

        savingsNote.text = "An estimate. Items you've used up count at the price you entered, or at this value if you left the price blank. It stays on your phone."
        savingsNote.font = Theme.Typography.caption.font
        savingsNote.textColor = Theme.Colors.muted
        savingsNote.numberOfLines = 0
        savingsNote.adjustsFontForContentSizeCategory = true

        datePreviewLabel.font = Theme.Typography.caption.font
        datePreviewLabel.textColor = Theme.Colors.muted
        datePreviewLabel.adjustsFontForContentSizeCategory = true

        // "Notifications are blocked" banner with a shortcut to iOS Settings
        bannerCard.backgroundColor = Theme.Colors.soonBackground
        bannerCard.layer.cornerRadius = 16
        bannerLabel.font = Theme.Typography.caption.font
        bannerLabel.textColor = Theme.Colors.soonText
        bannerLabel.numberOfLines = 0
        bannerLabel.adjustsFontForContentSizeCategory = true
        var openConfig = UIButton.Configuration.plain()
        openConfig.baseForegroundColor = Theme.Colors.soonText
        openConfig.contentInsets = .zero
        var openTitle = AttributedString("Open Settings")
        openTitle.font = Theme.Typography.button.font
        openConfig.attributedTitle = openTitle
        let openButton = UIButton(configuration: openConfig)
        openButton.contentHorizontalAlignment = .leading
        openButton.addAction(UIAction { [weak self] _ in self?.presenter?.didTapOpenSystemSettings() },
                             for: .touchUpInside)
        let bannerStack = UIStackView(arrangedSubviews: [bannerLabel, openButton])
        bannerStack.axis = .vertical
        bannerStack.spacing = 6
        bannerStack.alignment = .leading
        bannerStack.translatesAutoresizingMaskIntoConstraints = false
        bannerCard.addSubview(bannerStack)
        NSLayoutConstraint.activate([
            bannerStack.topAnchor.constraint(equalTo: bannerCard.topAnchor, constant: 14),
            bannerStack.bottomAnchor.constraint(equalTo: bannerCard.bottomAnchor, constant: -14),
            bannerStack.leadingAnchor.constraint(equalTo: bannerCard.leadingAnchor, constant: 16),
            bannerStack.trailingAnchor.constraint(equalTo: bannerCard.trailingAnchor, constant: -16)
        ])
        bannerRow = pad(bannerCard)
        bannerRow.isHidden = true // an unseen view must not leave a gap, so we hide the whole row

        // Rows
        let defaultReminderRow = FormCardRow(title: "Remind me", control: defaultReminderButton)
        let timeRow = FormCardRow(title: "At", control: reminderTimePicker)
        reminderRows = [defaultReminderRow, timeRow]

        let column = UIStackView(arrangedSubviews: [
            sectionHeader("REMINDERS"),
            card(FormCardRow(title: "Expiry reminders", control: notificationsSwitch)),
            bannerRow,
            card(defaultReminderRow),
            card(timeRow),
            sectionHeader("DATES"),
            card(FormCardRow(title: "Date format", control: dateFormatButton)),
            pad(datePreviewLabel),
            sectionHeader("COLOURS"),
            card(FormCardRow(title: "Turns red", control: urgentButton)),
            card(FormCardRow(title: "Turns amber", control: soonButton)),
            sectionHeader("SAVINGS"),
            card(FormCardRow(title: "Show money saved", control: moneySwitch)),
            card(FormCardRow(title: "Average item value", control: itemValueButton)),
            pad(savingsNote)
        ])
        column.axis = .vertical
        column.spacing = 10
        column.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(column)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            column.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            column.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -110),
            column.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            column.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }
}
