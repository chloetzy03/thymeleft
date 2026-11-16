import XCTest
@testable import thyme_left

@MainActor
final class AddEditItemPresenterTests: XCTestCase {

    // MARK: Pretend neighbours

    private final class ViewSpy: AddEditItemViewProtocol {
        var form: AddEditFormViewModel?
        var emoji: String?
        var expiryDate: Date?
        var nameError: String?
        var errorMessage: String?
        var primerShownCount = 0
        var shownPhotos: [Data?] = []
        var photoOptions: [[PhotoOption]] = []
        var pickerSources: [PhotoSource] = []

        func showForm(_ form: AddEditFormViewModel) { self.form = form }
        func showEmoji(_ emoji: String) { self.emoji = emoji }
        func showExpiryDate(_ date: Date) { expiryDate = date }
        func showNameError(_ message: String?) { nameError = message }
        func showError(message: String) { errorMessage = message }
        func showReminderPrimer() { primerShownCount += 1 }
        func showPhoto(_ data: Data?) { shownPhotos.append(data) }
        func showPhotoOptions(_ options: [PhotoOption]) { photoOptions.append(options) }
        func presentPhotoPicker(_ source: PhotoSource) { pickerSources.append(source) }
    }

    private final class InteractorSpy: AddEditItemInteractorInput {
        var savedDrafts: [PantryItemDraft] = []
        var replaced: [PantryItem?] = []
        var permissionRequestCount = 0

        func requestReminderPermission() { permissionRequestCount += 1 }

        func save(_ draft: PantryItemDraft, replacing existing: PantryItem?) {
            savedDrafts.append(draft)
            replaced.append(existing)
        }
    }

    private final class RouterSpy: AddEditItemRouterProtocol {
        var closeCount = 0
        var scannerOpenCount = 0
        var scannerResultHandler: ((ScanResult) -> Void)?

        func showScanner(onResult: @escaping (ScanResult) -> Void) {
            scannerOpenCount += 1
            scannerResultHandler = onResult
        }
        func close() { closeCount += 1 }
    }

    // MARK: Helpers

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var today: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 9))!
    }

    private func makeSUT(existing: PantryItem? = nil,
                         settings: AppSettings = AppSettings(),
                         photoStore: InMemoryPhotoStore? = nil,
                         prefill: ScanResult? = nil,
                         onSaved: @escaping () -> Void = {})
        -> (sut: AddEditItemPresenter, view: ViewSpy, interactor: InteractorSpy, router: RouterSpy) {
        let view = ViewSpy()
        let interactor = InteractorSpy()
        let router = RouterSpy()
        let sut = AddEditItemPresenter(view: view, interactor: interactor, router: router,
                                       iconProvider: EmojiFoodIconProvider(),
                                       dateProvider: FixedDateProvider(now: today),
                                       settingsStore: InMemorySettingsStore(settings: settings),
                                       photoStore: photoStore ?? InMemoryPhotoStore(),
                                       existingItem: existing, calendar: calendar,
                                       prefill: prefill, onSaved: onSaved)
        return (sut, view, interactor, router)
    }

    // MARK: Setting up the form

    func test_viewDidLoad_whenAdding_showsAnEmptyFormWithDefaults() async throws {
        // Arrange
        let (sut, view, _, _) = makeSUT()

        // Act
        sut.viewDidLoad()

        // Assert
        let form = try XCTUnwrap(view.form)
        XCTAssertEqual(form.title, "Add item")
        XCTAssertEqual(form.saveButtonTitle, "Add to pantry")
        XCTAssertEqual(form.name, "")
        XCTAssertEqual(form.quantity, 1)
        XCTAssertEqual(form.locationTitles, ["Fridge", "Pantry", "Freezer", "Counter"])
        XCTAssertEqual(form.selectedLocationIndex, 0)
        XCTAssertEqual(form.expiryDate, calendar.date(byAdding: .day, value: 7, to: today))
        XCTAssertEqual(form.quickDateTitles, ["Tomorrow", "3 days", "1 week", "1 month"])
    }

    func test_viewDidLoad_whenEditing_prefillsTheItem() async throws {
        // Arrange
        let expiry = calendar.date(byAdding: .day, value: 2, to: today)!
        let item = PantryItem(name: "Frozen peas", quantity: 4, location: .freezer, expiryDate: expiry)
        let (sut, view, _, _) = makeSUT(existing: item)

        // Act
        sut.viewDidLoad()

        // Assert
        let form = try XCTUnwrap(view.form)
        XCTAssertEqual(form.title, "Edit item")
        XCTAssertEqual(form.saveButtonTitle, "Save changes")
        XCTAssertEqual(form.name, "Frozen peas")
        XCTAssertEqual(form.emoji, "🫛")
        XCTAssertEqual(form.quantity, 4)
        XCTAssertEqual(form.selectedLocationIndex, 2)
        XCTAssertEqual(form.expiryDate, expiry)
    }

    // MARK: Typing and shortcuts

    func test_nameChanged_updatesTheEmojiAndClearsTheError() async {
        // Arrange
        let (sut, view, _, _) = makeSUT()
        sut.didFailValidation(.emptyName)

        // Act
        sut.nameChanged("milk")

        // Assert
        XCTAssertEqual(view.emoji, "🥛")
        XCTAssertNil(view.nameError)
    }

    func test_didSelectQuickDate_setsTheExpectedDate() async {
        // Arrange
        let (sut, view, _, _) = makeSUT()
        let expectations: [(index: Int, expected: DateComponents)] = [
            (0, DateComponents(day: 1)), (1, DateComponents(day: 3)),
            (2, DateComponents(day: 7)), (3, DateComponents(month: 1))
        ]

        for expectation in expectations {
            // Act
            sut.didSelectQuickDate(at: expectation.index)

            // Assert
            XCTAssertEqual(view.expiryDate, calendar.date(byAdding: expectation.expected, to: today),
                           "quick date #\(expectation.index)")
        }
    }

    func test_didSelectQuickDate_withInvalidIndex_doesNothing() async {
        // Arrange
        let (sut, view, _, _) = makeSUT()

        // Act
        sut.didSelectQuickDate(at: 42)

        // Assert
        XCTAssertNil(view.expiryDate)
    }

    // MARK: Saving and closing

    func test_didTapSave_handsTheDraftToTheInteractor() async {
        // Arrange
        let (sut, _, interactor, _) = makeSUT()
        sut.viewDidLoad() // the form must be on screen before anyone can tap Save

        // Act
        sut.didTapSave(name: "Milk", quantity: 2, locationIndex: 3, reminderIndex: 0, expiryDate: today)

        // Assert
        XCTAssertEqual(interactor.savedDrafts,
                       [PantryItemDraft(name: "Milk", quantity: 2, location: .counter, expiryDate: today)])
        XCTAssertEqual(interactor.replaced.count, 1)
        XCTAssertNil(interactor.replaced[0])
    }

    func test_didTapSave_whenEditing_tellsTheInteractorWhichItemToReplace() async {
        // Arrange
        let item = PantryItem(name: "Milk", location: .fridge, expiryDate: today)
        let (sut, _, interactor, _) = makeSUT(existing: item)
        sut.viewDidLoad()

        // Act
        sut.didTapSave(name: "Oat milk", quantity: 1, locationIndex: 0, reminderIndex: 0, expiryDate: today)

        // Assert
        XCTAssertEqual(interactor.replaced.first??.id, item.id)
    }

    func test_didTapSave_withInvalidLocationIndex_doesNothing() async {
        // Arrange
        let (sut, _, interactor, _) = makeSUT()

        // Act
        sut.didTapSave(name: "Milk", quantity: 1, locationIndex: 99, reminderIndex: 0, expiryDate: today)

        // Assert
        XCTAssertTrue(interactor.savedDrafts.isEmpty)
    }

    func test_didSave_notifiesThePreviousScreenAndCloses() async {
        // Arrange
        var savedCallbackCount = 0
        let (sut, _, _, router) = makeSUT(onSaved: { savedCallbackCount += 1 })

        // Act
        sut.didSave(shouldExplainReminders: false)

        // Assert
        XCTAssertEqual(savedCallbackCount, 1)
        XCTAssertEqual(router.closeCount, 1)
    }

    func test_didTapCancel_closesWithoutNotifying() async {
        // Arrange
        var savedCallbackCount = 0
        let (sut, _, _, router) = makeSUT(onSaved: { savedCallbackCount += 1 })

        // Act
        sut.didTapCancel()

        // Assert
        XCTAssertEqual(router.closeCount, 1)
        XCTAssertEqual(savedCallbackCount, 0)
    }

    // MARK: Problems

    func test_didFailValidation_showsFriendlyMessages() async {
        // Arrange
        let (sut, view, _, _) = makeSUT()

        // Act + Assert, one problem at a time
        sut.didFailValidation(.emptyName)
        XCTAssertEqual(view.nameError, "Please give this item a name.")

        sut.didFailValidation(.nameTooLong(max: 40))
        XCTAssertEqual(view.nameError, "That name is too long. Please use 40 characters or fewer.")

        sut.didFailValidation(.invalidQuantity)
        XCTAssertEqual(view.errorMessage, "Quantity must be between 1 and 99.")
    }

    func test_didFail_showsASaveErrorMessage() async {
        // Arrange
        let (sut, view, _, _) = makeSUT()

        // Act
        sut.didFail(NSError(domain: "test", code: 1))

        // Assert
        XCTAssertEqual(view.errorMessage, "We couldn't save this item. Please try again.")
    }

    // MARK: Reminders

    func test_viewDidLoad_offersTheReminderChoicesWithTheCurrentDefaultSpelledOut() async throws {
        // Arrange
        var settings = AppSettings()
        settings.defaultReminderDaysBefore = 2
        let (sut, view, _, _) = makeSUT(settings: settings)

        // Act
        sut.viewDidLoad()

        // Assert
        let form = try XCTUnwrap(view.form)
        XCTAssertEqual(form.reminderTitles, ["Default (2 days before)", "Never", "Same day",
                                             "1 day before", "2 days before", "3 days before", "1 week before"])
        XCTAssertEqual(form.selectedReminderIndex, 0)
    }

    func test_viewDidLoad_whenEditing_selectsTheItemsOwnReminder() async throws {
        // Arrange
        let item = PantryItem(name: "Milk", location: .fridge, expiryDate: today, reminder: .daysBefore(3))
        let (sut, view, _, _) = makeSUT(existing: item)

        // Act
        sut.viewDidLoad()

        // Assert
        XCTAssertEqual(view.form?.selectedReminderIndex, 5) // "3 days before"
    }

    func test_didTapSave_turnsTheChosenReminderIntoAPreference() async {
        // Arrange
        let (sut, _, interactor, _) = makeSUT()
        sut.viewDidLoad() // builds the reminder options
        let choices: [(index: Int, expected: ReminderPreference)] = [
            (0, .useDefault), (1, .never), (2, .daysBefore(0)), (5, .daysBefore(3)), (6, .daysBefore(7))
        ]

        for choice in choices {
            // Act
            sut.didTapSave(name: "Milk", quantity: 1, locationIndex: 0, reminderIndex: choice.index, expiryDate: today)

            // Assert
            XCTAssertEqual(interactor.savedDrafts.last?.reminder, choice.expected, "option #\(choice.index)")
        }
    }

    func test_didSave_whenTheExplainerIsNeeded_showsItInsteadOfClosing() async {
        // Arrange
        var savedCallbackCount = 0
        let (sut, view, _, router) = makeSUT(onSaved: { savedCallbackCount += 1 })

        // Act
        sut.didSave(shouldExplainReminders: true)

        // Assert
        XCTAssertEqual(view.primerShownCount, 1)
        XCTAssertEqual(router.closeCount, 0)
        XCTAssertEqual(savedCallbackCount, 0)
    }

    func test_answeringYesToTheExplainer_asksForPermissionThenClosesWhenDone() async {
        // Arrange
        var savedCallbackCount = 0
        let (sut, _, interactor, router) = makeSUT(onSaved: { savedCallbackCount += 1 })

        // Act
        sut.didRespondToReminderPrimer(allow: true)
        let closedBeforeAnswer = router.closeCount
        sut.didFinishReminderPermission() // iOS's pop-up has been answered

        // Assert
        XCTAssertEqual(interactor.permissionRequestCount, 1)
        XCTAssertEqual(closedBeforeAnswer, 0)
        XCTAssertEqual(router.closeCount, 1)
        XCTAssertEqual(savedCallbackCount, 1)
    }

    func test_answeringNotNowToTheExplainer_closesWithoutAskingIOS() async {
        // Arrange
        var savedCallbackCount = 0
        let (sut, _, interactor, router) = makeSUT(onSaved: { savedCallbackCount += 1 })

        // Act
        sut.didRespondToReminderPrimer(allow: false)

        // Assert
        XCTAssertEqual(interactor.permissionRequestCount, 0)
        XCTAssertEqual(router.closeCount, 1)
        XCTAssertEqual(savedCallbackCount, 1)
    }

    // MARK: Photos

    private let picture = Data([1, 2, 3])

    func test_viewDidLoad_whenEditingAnItemWithAPhoto_showsThatPhoto() async throws {
        // Arrange
        let photos = InMemoryPhotoStore()
        let name = try photos.savePhoto(picture)
        let item = PantryItem(name: "Milk", location: .fridge, expiryDate: today, photoFileName: name)
        let (sut, view, _, _) = makeSUT(existing: item, photoStore: photos)

        // Act
        sut.viewDidLoad()

        // Assert
        XCTAssertEqual(view.form?.photoData, picture)
    }

    func test_viewDidLoad_whenAdding_hasNoPhoto() async {
        // Arrange
        let (sut, view, _, _) = makeSUT()

        // Act
        sut.viewDidLoad()

        // Assert
        XCTAssertNil(view.form?.photoData)
    }

    func test_didTapPhoto_offersCameraAndLibrary_butRemoveOnlyWhenThereIsAPhoto() async throws {
        // Arrange
        let photos = InMemoryPhotoStore()
        let name = try photos.savePhoto(picture)
        let withoutPhoto = makeSUT()
        let withPhoto = makeSUT(existing: PantryItem(name: "Milk", location: .fridge, expiryDate: today,
                                                     photoFileName: name), photoStore: photos)

        // Act
        withoutPhoto.sut.didTapPhoto()
        withPhoto.sut.didTapPhoto()

        // Assert
        XCTAssertEqual(withoutPhoto.view.photoOptions, [[.takePhoto, .chooseFromLibrary]])
        XCTAssertEqual(withPhoto.view.photoOptions, [[.takePhoto, .chooseFromLibrary, .removePhoto]])
    }

    func test_didSelectPhotoOption_opensTheRightPicker() async {
        // Arrange
        let (sut, view, _, _) = makeSUT()

        // Act
        sut.didSelectPhotoOption(.takePhoto)
        sut.didSelectPhotoOption(.chooseFromLibrary)

        // Assert
        XCTAssertEqual(view.pickerSources, [.camera, .library])
    }

    func test_didPickPhoto_showsItAndIncludesItInTheDraft() async {
        // Arrange
        let (sut, view, interactor, _) = makeSUT()
        sut.viewDidLoad()

        // Act
        sut.didPickPhoto(picture)
        sut.didTapSave(name: "Milk", quantity: 1, locationIndex: 0, reminderIndex: 0, expiryDate: today)

        // Assert
        XCTAssertEqual(view.shownPhotos.last ?? nil, picture)
        XCTAssertEqual(interactor.savedDrafts.last?.photo, .replace(picture))
    }

    func test_removingAnExistingPhoto_showsTheEmojiAndMarksItForRemoval() async throws {
        // Arrange
        let photos = InMemoryPhotoStore()
        let name = try photos.savePhoto(picture)
        let item = PantryItem(name: "Milk", location: .fridge, expiryDate: today, photoFileName: name)
        let (sut, view, interactor, _) = makeSUT(existing: item, photoStore: photos)
        sut.viewDidLoad()

        // Act
        sut.didSelectPhotoOption(.removePhoto)
        sut.didTapSave(name: "Milk", quantity: 1, locationIndex: 0, reminderIndex: 0, expiryDate: today)
        sut.didTapPhoto()

        // Assert
        XCTAssertEqual(view.shownPhotos.count, 1)
        XCTAssertNil(view.shownPhotos[0])
        XCTAssertEqual(interactor.savedDrafts.last?.photo, .remove)
        XCTAssertEqual(view.photoOptions.last, [.takePhoto, .chooseFromLibrary], "nothing left to remove")
    }

    func test_pickingThenRemoving_onAnItemWithoutAPhoto_changesNothing() async {
        // Arrange
        let (sut, _, interactor, _) = makeSUT()
        sut.viewDidLoad()

        // Act
        sut.didPickPhoto(picture)
        sut.didSelectPhotoOption(.removePhoto)
        sut.didTapSave(name: "Milk", quantity: 1, locationIndex: 0, reminderIndex: 0, expiryDate: today)

        // Assert: there was never a saved photo, so there is nothing to remove or replace
        XCTAssertEqual(interactor.savedDrafts.last?.photo, .keep)
    }

    // MARK: Scanning

    func test_didTapScan_opensTheScanner() async {
        // Arrange
        let (sut, _, _, router) = makeSUT()

        // Act
        sut.didTapScan()

        // Assert
        XCTAssertEqual(router.scannerOpenCount, 1)
    }

    func test_whenTheScannerReturnsADate_theFormShowsIt() async {
        // Arrange
        let (sut, view, _, router) = makeSUT()
        sut.didTapScan()

        // Act: the scanner hands back a result
        router.scannerResultHandler?(ScanResult(date: today, photoData: nil))

        // Assert
        XCTAssertEqual(view.expiryDate, today)
        XCTAssertTrue(view.shownPhotos.isEmpty, "no photo was kept")
    }

    func test_whenTheScannerAlsoReturnsAPhoto_itBecomesTheItemsPhoto() async {
        // Arrange
        let (sut, view, interactor, _) = makeSUT()
        sut.viewDidLoad()
        let pack = Data([9, 9, 9])

        // Act
        sut.didScan(ScanResult(date: today, photoData: pack))
        sut.didTapSave(name: "Milk", quantity: 1, locationIndex: 0, reminderIndex: 0, expiryDate: today)

        // Assert
        XCTAssertEqual(view.shownPhotos.last ?? nil, pack)
        XCTAssertEqual(interactor.savedDrafts.last?.photo, .replace(pack))
    }

    func test_prefill_fillsTheNewFormWithTheScannedDateAndPhoto() async throws {
        // Arrange
        let expiry = calendar.date(byAdding: .day, value: 3, to: today)!
        let pack = Data([4, 5, 6])
        let (sut, view, interactor, _) = makeSUT(prefill: ScanResult(date: expiry, photoData: pack))

        // Act
        sut.viewDidLoad()
        sut.didTapSave(name: "Yoghurt", quantity: 1, locationIndex: 0, reminderIndex: 0, expiryDate: expiry)

        // Assert
        let form = try XCTUnwrap(view.form)
        XCTAssertEqual(form.expiryDate, expiry)
        XCTAssertEqual(form.photoData, pack)
        XCTAssertEqual(interactor.savedDrafts.last?.photo, .replace(pack))
    }

    func test_prefillWithoutAPhoto_onlySetsTheDate() async throws {
        // Arrange
        let expiry = calendar.date(byAdding: .day, value: 2, to: today)!
        let (sut, view, interactor, _) = makeSUT(prefill: ScanResult(date: expiry, photoData: nil))

        // Act
        sut.viewDidLoad()
        sut.didTapSave(name: "Milk", quantity: 1, locationIndex: 0, reminderIndex: 0, expiryDate: expiry)

        // Assert
        XCTAssertEqual(view.form?.expiryDate, expiry)
        XCTAssertNil(view.form?.photoData)
        XCTAssertEqual(interactor.savedDrafts.last?.photo, .keep)
    }

    func test_prefill_photoCanStillBeRemovedBeforeSaving() async {
        // Arrange
        let (sut, _, interactor, _) = makeSUT(prefill: ScanResult(date: today, photoData: Data([1])))
        sut.viewDidLoad()

        // Act
        sut.didSelectPhotoOption(.removePhoto)
        sut.didTapSave(name: "Milk", quantity: 1, locationIndex: 0, reminderIndex: 0, expiryDate: today)

        // Assert: there was never a SAVED photo, so nothing to replace or remove
        XCTAssertEqual(interactor.savedDrafts.last?.photo, .keep)
    }
}
