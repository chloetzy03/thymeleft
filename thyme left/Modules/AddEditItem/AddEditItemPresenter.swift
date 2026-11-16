import Foundation

/// The manager of the Add / Edit screen: sets up the form and turns results into messages.
@MainActor
final class AddEditItemPresenter: AddEditItemPresenterProtocol, AddEditItemInteractorOutput {

    /// The shortcut buttons under the date picker.
    private struct QuickDate {
        let title: String
        let offset: DateComponents
    }
    private let quickDates = [
        QuickDate(title: "Tomorrow", offset: DateComponents(day: 1)),
        QuickDate(title: "3 days", offset: DateComponents(day: 3)),
        QuickDate(title: "1 week", offset: DateComponents(day: 7)),
        QuickDate(title: "1 month", offset: DateComponents(month: 1))
    ]

    /// A brand-new item starts with an expiry date one week from today.
    private static let defaultDaysUntilExpiry = 7

    private weak var view: AddEditItemViewProtocol?
    private let interactor: AddEditItemInteractorInput
    private let router: AddEditItemRouterProtocol
    private let iconProvider: FoodIconProviding
    private let dateProvider: DateProviding
    private let settingsStore: SettingsStore
    private let photoStore: PhotoStoring
    private let formatter: ExpiryTextFormatter
    private let calendar: Calendar
    /// Decides whether "3.50" or "3,50" is the right way to write a price.
    private let locale: Locale
    private let existingItem: PantryItem?
    /// Called after a successful save, so the previous screen can refresh itself.
    private let onSaved: () -> Void
    /// A scan done BEFORE the form opened (from the Scan tab): its date and photo fill the new form.
    private let prefill: ScanResult?

    /// What the user has decided about the photo so far (nothing is saved until they tap Save).
    private var photoChange: PhotoChange = .keep
    private var hasPhoto: Bool
    private var dateType: DateType
    private var priceText: String

    private let locations = StorageLocation.allCases
    /// The "Remind me" choices, in the order they appear. Filled in when the form loads.
    private var reminderOptions: [(title: String, preference: ReminderPreference)] = []

    init(view: AddEditItemViewProtocol,
         interactor: AddEditItemInteractorInput,
         router: AddEditItemRouterProtocol,
         iconProvider: FoodIconProviding,
         dateProvider: DateProviding,
         settingsStore: SettingsStore,
         photoStore: PhotoStoring,
         existingItem: PantryItem?,
         formatter: ExpiryTextFormatter = ExpiryTextFormatter(),
         calendar: Calendar = .current,
         locale: Locale = .current,
         prefill: ScanResult? = nil,
         onSaved: @escaping () -> Void) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.iconProvider = iconProvider
        self.dateProvider = dateProvider
        self.settingsStore = settingsStore
        self.photoStore = photoStore
        self.existingItem = existingItem
        self.hasPhoto = existingItem?.photoFileName != nil || prefill?.photoData != nil
        self.photoChange = prefill?.photoData.map { .replace($0) } ?? .keep
        self.formatter = formatter
        self.calendar = calendar
        self.locale = locale
        self.dateType = existingItem?.dateType ?? .bestBefore
        self.priceText = Self.priceText(for: existingItem?.price, locale: locale)
        self.prefill = prefill
        self.onSaved = onSaved
    }

    // MARK: Things the View tells us

    func viewDidLoad() {
        let name = existingItem?.name ?? ""
        let location = existingItem?.location ?? .fridge
        let defaultExpiry = calendar.date(byAdding: .day, value: Self.defaultDaysUntilExpiry,
                                          to: dateProvider.now) ?? dateProvider.now

        reminderOptions = makeReminderOptions()
        let reminder = existingItem?.reminder ?? .useDefault

        view?.showForm(AddEditFormViewModel(
            title: existingItem == nil ? "Add item" : "Edit item",
            saveButtonTitle: existingItem == nil ? "Add to pantry" : "Save changes",
            name: name,
            emoji: iconProvider.emoji(for: name),
            quantity: existingItem?.quantity ?? 1,
            quantityRange: PantryItemRules.quantityRange,
            locationTitles: locations.map(\.displayName),
            selectedLocationIndex: locations.firstIndex(of: location) ?? 0,
            reminderTitles: reminderOptions.map(\.title),
            selectedReminderIndex: reminderOptions.firstIndex { $0.preference == reminder } ?? 0,
            photoData: existingItem?.photoFileName.flatMap { photoStore.photoData(named: $0) } ?? prefill?.photoData,
            expiryDate: existingItem?.expiryDate ?? prefill?.date ?? defaultExpiry,
            quickDateTitles: quickDates.map(\.title),
            dateTypeTitles: DateType.allCases.map(\.displayName),
            selectedDateTypeIndex: DateType.allCases.firstIndex(of: dateType) ?? 0,
            priceText: priceText))
    }

    func didTapScan() {
        router.showScanner { [weak self] result in self?.didScan(result) }
    }

    func didScan(_ result: ScanResult) {
        view?.showExpiryDate(result.date)
        if let photo = result.photoData { didPickPhoto(photo) } // the user chose to keep the pack photo
    }

    func nameChanged(_ text: String) {
        view?.showEmoji(iconProvider.emoji(for: text))
        view?.showNameError(nil) // the user is fixing it, so hide the old message
    }

    func didSelectQuickDate(at index: Int) {
        guard quickDates.indices.contains(index),
              let date = calendar.date(byAdding: quickDates[index].offset, to: dateProvider.now) else { return }
        view?.showExpiryDate(date)
    }

    func didSelectDateType(at index: Int) {
        guard DateType.allCases.indices.contains(index) else { return }
        dateType = DateType.allCases[index]
    }

    func didChangePrice(_ text: String) {
        priceText = text
        view?.showPriceError(nil) // the user is fixing it, so hide the old message
    }

    func didTapPhoto() {
        var options: [PhotoOption] = [.takePhoto, .chooseFromLibrary]
        if hasPhoto { options.append(.removePhoto) }
        view?.showPhotoOptions(options)
    }

    func didSelectPhotoOption(_ option: PhotoOption) {
        switch option {
        case .takePhoto:
            view?.presentPhotoPicker(.camera)
        case .chooseFromLibrary:
            view?.presentPhotoPicker(.library)
        case .removePhoto:
            // Only an item that already HAS a saved photo needs a "remove" later.
            photoChange = existingItem?.photoFileName == nil ? .keep : .remove
            hasPhoto = false
            view?.showPhoto(nil)
        }
    }

    func didPickPhoto(_ data: Data) {
        photoChange = .replace(data)
        hasPhoto = true
        view?.showPhoto(data)
    }

    func didTapSave(name: String, quantity: Int, locationIndex: Int, reminderIndex: Int, expiryDate: Date) {
        guard locations.indices.contains(locationIndex),
              reminderOptions.indices.contains(reminderIndex) else { return }
        // The price is optional: empty is fine, but something that isn't a number is not.
        let trimmedPrice = priceText.trimmingCharacters(in: .whitespacesAndNewlines)
        var price: Double?
        if !trimmedPrice.isEmpty {
            guard let parsed = Self.parsePrice(trimmedPrice, locale: locale) else {
                view?.showPriceError("Please enter the price as a number, like 3.50.")
                return
            }
            price = parsed
        }
        let draft = PantryItemDraft(name: name, quantity: quantity,
                                    location: locations[locationIndex],
                                    expiryDate: expiryDate,
                                    dateType: dateType,
                                    price: price,
                                    reminder: reminderOptions[reminderIndex].preference,
                                    photo: photoChange)
        interactor.save(draft, replacing: existingItem)
    }

    func didRespondToReminderPrimer(allow: Bool) {
        if allow {
            interactor.requestReminderPermission() // iOS shows its own pop-up now
        } else {
            finish()
        }
    }

    func didTapCancel() {
        router.close()
    }

    // MARK: Things the Interactor tells us

    func didSave(shouldExplainReminders: Bool) {
        if shouldExplainReminders {
            view?.showReminderPrimer() // we close the form once the user has answered
        } else {
            finish()
        }
    }

    func didFinishReminderPermission() {
        finish()
    }

    func didFailValidation(_ error: ItemValidationError) {
        switch error {
        case .emptyName:
            view?.showNameError("Please give this item a name.")
        case .nameTooLong(let max):
            view?.showNameError("That name is too long. Please use \(max) characters or fewer.")
        case .invalidQuantity:
            let range = PantryItemRules.quantityRange
            view?.showError(message: "Quantity must be between \(range.lowerBound) and \(range.upperBound).")
        case .invalidPrice:
            view?.showPriceError("That price doesn't look right. Please check it.")
        }
    }

    func didFail(_ error: Error) {
        view?.showError(message: "We couldn't save this item. Please try again.")
    }

    // MARK: Helpers

    /// Turns "3,50" or "3.50" (whatever the phone's region uses) into a number. Nil if it isn't one.
    private static func parsePrice(_ text: String, locale: Locale) -> Double? {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        return formatter.number(from: text)?.doubleValue
    }

    /// The reverse: shows an existing price the way the user would type it ("3.5", not "3.500000").
    private static func priceText(for price: Double?, locale: Locale) -> String {
        guard let price else { return "" }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: price)) ?? ""
    }

    private func finish() {
        onSaved()
        router.close()
    }

    /// "Default (1 day before)" first, so the user can see what "default" currently means.
    private func makeReminderOptions() -> [(title: String, preference: ReminderPreference)] {
        let defaultDays = settingsStore.load().defaultReminderDaysBefore
        var options: [(String, ReminderPreference)] = [
            ("Default (\(formatter.reminderLeadText(daysBefore: defaultDays).lowercased()))", .useDefault),
            ("Never", .never)
        ]
        for days in SettingsChoices.reminderDaysBefore {
            options.append((formatter.reminderLeadText(daysBefore: days), .daysBefore(days)))
        }
        return options
    }
}
