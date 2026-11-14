import XCTest
@testable import thyme_left

@MainActor
final class AddEditItemInteractorTests: XCTestCase {

    // MARK: Pretend neighbours

    private final class OutputSpy: AddEditItemInteractorOutput {
        var saveCount = 0
        var explainFlags: [Bool] = []
        var permissionFinished: XCTestExpectation?
        var validationErrors: [ItemValidationError] = []
        var failureCount = 0

        func didSave(shouldExplainReminders: Bool) { saveCount += 1; explainFlags.append(shouldExplainReminders) }
        func didFinishReminderPermission() { permissionFinished?.fulfill() }
        func didFailValidation(_ error: ItemValidationError) { validationErrors.append(error) }
        func didFail(_ error: Error) { failureCount += 1 }
    }

    /// A repository whose saving always fails. (Translation: lets us test the "disk full" case.)
    private final class FailingRepository: PantryRepository {
        struct Failure: Error {}
        func fetchAll() throws -> [PantryItem] { [] }
        func save(_ item: PantryItem) throws { throw Failure() }
        func delete(id: UUID) throws {}
    }

    // MARK: Helpers

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private struct SUT {
        let sut: AddEditItemInteractor
        let output: OutputSpy
        let repository: PantryRepository
        let settings: InMemorySettingsStore
        let reminders: ReminderServiceSpy
        let photos: InMemoryPhotoStore
    }

    private func makeSUT(repository: PantryRepository? = nil,
                         settings: AppSettings = AppSettings(),
                         permission: NotificationPermission = .authorized,
                         photos: InMemoryPhotoStore? = nil) -> SUT {
        let repository = repository ?? InMemoryPantryRepository()
        let store = InMemorySettingsStore(settings: settings)
        let reminders = ReminderServiceSpy(permission: permission)
        let photos = photos ?? InMemoryPhotoStore()
        let sut = AddEditItemInteractor(repository: repository, dateProvider: FixedDateProvider(now: now),
                                        settingsStore: store, reminders: reminders, photoStore: photos)
        let output = OutputSpy()
        sut.output = output
        return SUT(sut: sut, output: output, repository: repository, settings: store,
                   reminders: reminders, photos: photos)
    }

    private func makeDraft(name: String = "Milk", quantity: Int = 1) -> PantryItemDraft {
        PantryItemDraft(name: name, quantity: quantity, location: .fridge,
                        expiryDate: now.addingTimeInterval(86_400 * 3))
    }

    // MARK: Tests

    func test_save_withValidDraft_savesTheItemAndTellsOutput() async throws {
        // Arrange
        let made = makeSUT()
        let (sut, output, repository) = (made.sut, made.output, made.repository)

        // Act
        sut.save(makeDraft(name: "Milk", quantity: 2), replacing: nil)

        // Assert
        XCTAssertEqual(output.saveCount, 1)
        let saved = try XCTUnwrap(try repository.fetchAll().first)
        XCTAssertEqual(saved.name, "Milk")
        XCTAssertEqual(saved.quantity, 2)
        XCTAssertEqual(saved.createdAt, now)
    }

    func test_save_trimsSpacesAroundTheName() async throws {
        // Arrange
        let made = makeSUT()
        let (sut, repository) = (made.sut, made.repository)

        // Act
        sut.save(makeDraft(name: "   Milk \n"), replacing: nil)

        // Assert
        XCTAssertEqual(try repository.fetchAll().first?.name, "Milk")
    }

    func test_save_withBlankName_isRejectedAndNothingIsSaved() async throws {
        // Arrange
        let made = makeSUT()
        let (sut, output, repository) = (made.sut, made.output, made.repository)

        // Act
        sut.save(makeDraft(name: "   "), replacing: nil)

        // Assert
        XCTAssertEqual(output.validationErrors, [.emptyName])
        XCTAssertEqual(output.saveCount, 0)
        XCTAssertTrue(try repository.fetchAll().isEmpty)
    }

    func test_save_withNameOverTheLimit_isRejected() async {
        // Arrange
        let made = makeSUT()
        let (sut, output) = (made.sut, made.output)
        let tooLong = String(repeating: "a", count: PantryItemRules.maxNameLength + 1)

        // Act
        sut.save(makeDraft(name: tooLong), replacing: nil)

        // Assert
        XCTAssertEqual(output.validationErrors, [.nameTooLong(max: PantryItemRules.maxNameLength)])
    }

    func test_save_withNameExactlyAtTheLimit_isAccepted() async {
        // Arrange
        let made = makeSUT()
        let (sut, output) = (made.sut, made.output)
        let atLimit = String(repeating: "a", count: PantryItemRules.maxNameLength)

        // Act
        sut.save(makeDraft(name: atLimit), replacing: nil)

        // Assert
        XCTAssertEqual(output.saveCount, 1)
    }

    func test_save_withQuantityOutsideTheRange_isRejected() async {
        // Arrange
        let made = makeSUT()
        let (sut, output) = (made.sut, made.output)

        // Act
        sut.save(makeDraft(quantity: 0), replacing: nil)
        sut.save(makeDraft(quantity: 100), replacing: nil)

        // Assert
        XCTAssertEqual(output.validationErrors, [.invalidQuantity, .invalidQuantity])
    }

    func test_save_whenEditing_keepsTheOriginalIdAndDateAdded() async throws {
        // Arrange
        let original = PantryItem(name: "Milk", quantity: 1, location: .fridge,
                                  expiryDate: now, createdAt: now.addingTimeInterval(-5_000))
        let repository = InMemoryPantryRepository(items: [original])
        let sut = makeSUT(repository: repository).sut

        // Act
        sut.save(makeDraft(name: "Oat milk", quantity: 3), replacing: original)

        // Assert: still ONE item, with the same identity but new details
        let items = try repository.fetchAll()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.id, original.id)
        XCTAssertEqual(items.first?.createdAt, original.createdAt)
        XCTAssertEqual(items.first?.name, "Oat milk")
        XCTAssertEqual(items.first?.quantity, 3)
    }

    func test_save_whenTheRepositoryFails_reportsAFailure() async {
        // Arrange
        let made = makeSUT(repository: FailingRepository())
        let (sut, output) = (made.sut, made.output)

        // Act
        sut.save(makeDraft(), replacing: nil)

        // Assert
        XCTAssertEqual(output.failureCount, 1)
        XCTAssertEqual(output.saveCount, 0)
    }

    // MARK: Reminders

    func test_save_storesTheItemsReminderChoiceAndReplansReminders() async throws {
        // Arrange
        let made = makeSUT()
        var draft = makeDraft()
        draft.reminder = .daysBefore(3)

        // Act
        made.sut.save(draft, replacing: nil)

        // Assert
        XCTAssertEqual(try made.repository.fetchAll().first?.reminder, .daysBefore(3))
        XCTAssertEqual(made.reminders.rescheduleCount, 1)
    }

    func test_save_whenPermissionNotAskedYet_explainsRemindersOnlyOnce() async {
        // Arrange
        let made = makeSUT(permission: .notDetermined)

        // Act
        made.sut.save(makeDraft(), replacing: nil)
        made.sut.save(makeDraft(name: "Eggs"), replacing: nil)

        // Assert: the explainer appears for the first save only, so we never nag
        XCTAssertEqual(made.output.explainFlags, [true, false])
        XCTAssertTrue(made.settings.load().hasSeenReminderPrimer)
    }

    func test_save_doesNotExplainWhenNoReminderWouldBeSent() async {
        // Arrange: (permission not asked yet) but the item says "never remind me"
        let neverRemind = makeSUT(permission: .notDetermined)
        var draft = makeDraft()
        draft.reminder = .never

        var notificationsOff = AppSettings()
        notificationsOff.notificationsEnabled = false
        let switchedOff = makeSUT(settings: notificationsOff, permission: .notDetermined)

        // Act
        neverRemind.sut.save(draft, replacing: nil)
        switchedOff.sut.save(makeDraft(), replacing: nil)

        // Assert
        XCTAssertEqual(neverRemind.output.explainFlags, [false])
        XCTAssertEqual(switchedOff.output.explainFlags, [false])
    }

    func test_save_doesNotExplainWhenPermissionAlreadyDecided() async {
        // Arrange
        let allowed = makeSUT(permission: .authorized)
        let denied = makeSUT(permission: .denied)

        // Act
        allowed.sut.save(makeDraft(), replacing: nil)
        denied.sut.save(makeDraft(), replacing: nil)

        // Assert
        XCTAssertEqual(allowed.output.explainFlags, [false])
        XCTAssertEqual(denied.output.explainFlags, [false])
    }

    func test_requestReminderPermission_asksTheServiceThenTellsOutput() async {
        // Arrange
        let made = makeSUT(permission: .notDetermined)
        let finished = expectation(description: "permission request finished")
        made.output.permissionFinished = finished

        // Act
        made.sut.requestReminderPermission()
        await fulfillment(of: [finished], timeout: 2)

        // Assert
        XCTAssertEqual(made.reminders.requestCount, 1)
    }

    // MARK: Photos

    private let tinyPicture = Data([0xFF, 0xD8, 0xFF, 0xD9]) // stands in for a picture; the fake store doesn't look inside

    func test_save_withANewPhoto_storesItAndRemembersTheFileName() async throws {
        // Arrange
        let made = makeSUT()
        var draft = makeDraft()
        draft.photo = .replace(tinyPicture)

        // Act
        made.sut.save(draft, replacing: nil)

        // Assert
        let saved = try XCTUnwrap(try made.repository.fetchAll().first)
        let fileName = try XCTUnwrap(saved.photoFileName)
        XCTAssertEqual(made.photos.photoData(named: fileName), tinyPicture)
    }

    func test_save_replacingAPhoto_deletesTheOldFileOnceSaved() async throws {
        // Arrange
        let photos = InMemoryPhotoStore()
        let oldName = try photos.savePhoto(tinyPicture)
        let original = PantryItem(name: "Milk", location: .fridge, expiryDate: now, photoFileName: oldName)
        let made = makeSUT(repository: InMemoryPantryRepository(items: [original]), photos: photos)
        var draft = makeDraft()
        draft.photo = .replace(Data([1, 2, 3]))

        // Act
        made.sut.save(draft, replacing: original)

        // Assert
        let newName = try XCTUnwrap(try made.repository.fetchAll().first?.photoFileName)
        XCTAssertNotEqual(newName, oldName)
        XCTAssertNil(photos.photoData(named: oldName), "the old picture should be gone")
        XCTAssertNotNil(photos.photoData(named: newName))
        XCTAssertEqual(photos.photos.count, 1, "no leftover files")
    }

    func test_save_removingAPhoto_deletesTheFileAndClearsTheName() async throws {
        // Arrange
        let photos = InMemoryPhotoStore()
        let oldName = try photos.savePhoto(tinyPicture)
        let original = PantryItem(name: "Milk", location: .fridge, expiryDate: now, photoFileName: oldName)
        let made = makeSUT(repository: InMemoryPantryRepository(items: [original]), photos: photos)
        var draft = makeDraft()
        draft.photo = .remove

        // Act
        made.sut.save(draft, replacing: original)

        // Assert
        XCTAssertNil(try made.repository.fetchAll().first?.photoFileName)
        XCTAssertTrue(photos.photos.isEmpty)
    }

    func test_save_keepingThePhoto_leavesItUntouched() async throws {
        // Arrange
        let photos = InMemoryPhotoStore()
        let name = try photos.savePhoto(tinyPicture)
        let original = PantryItem(name: "Milk", location: .fridge, expiryDate: now, photoFileName: name)
        let made = makeSUT(repository: InMemoryPantryRepository(items: [original]), photos: photos)

        // Act
        made.sut.save(makeDraft(name: "Oat milk"), replacing: original) // photo defaults to .keep

        // Assert
        XCTAssertEqual(try made.repository.fetchAll().first?.photoFileName, name)
        XCTAssertNotNil(photos.photoData(named: name))
    }

    func test_save_whenThePhotoCannotBeStored_failsAndSavesNothing() async throws {
        // Arrange
        let photos = InMemoryPhotoStore()
        photos.shouldFailToSave = true
        let made = makeSUT(photos: photos)
        var draft = makeDraft()
        draft.photo = .replace(tinyPicture)

        // Act
        made.sut.save(draft, replacing: nil)

        // Assert
        XCTAssertEqual(made.output.failureCount, 1)
        XCTAssertEqual(made.output.saveCount, 0)
        XCTAssertTrue(try made.repository.fetchAll().isEmpty)
    }

    func test_save_whenTheItemCannotBeSaved_cleansUpTheNewPhotoFile() async {
        // Arrange
        let photos = InMemoryPhotoStore()
        let made = makeSUT(repository: FailingRepository(), photos: photos)
        var draft = makeDraft()
        draft.photo = .replace(tinyPicture)

        // Act
        made.sut.save(draft, replacing: nil)

        // Assert
        XCTAssertEqual(made.output.failureCount, 1)
        XCTAssertTrue(photos.photos.isEmpty, "the new picture must not be left behind")
    }
}
