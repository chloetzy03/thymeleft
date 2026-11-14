import XCTest
@testable import thyme_left

@MainActor
final class AddEditItemInteractorTests: XCTestCase {

    // MARK: Pretend neighbours

    private final class OutputSpy: AddEditItemInteractorOutput {
        var saveCount = 0
        var validationErrors: [ItemValidationError] = []
        var failureCount = 0

        func didSave() { saveCount += 1 }
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

    private func makeSUT(repository: PantryRepository? = nil)
        -> (sut: AddEditItemInteractor, output: OutputSpy, repository: PantryRepository) {
        let repository = repository ?? InMemoryPantryRepository()
        let sut = AddEditItemInteractor(repository: repository, dateProvider: FixedDateProvider(now: now))
        let output = OutputSpy()
        sut.output = output
        return (sut, output, repository)
    }

    private func makeDraft(name: String = "Milk", quantity: Int = 1) -> PantryItemDraft {
        PantryItemDraft(name: name, quantity: quantity, location: .fridge,
                        expiryDate: now.addingTimeInterval(86_400 * 3))
    }

    // MARK: Tests

    func test_save_withValidDraft_savesTheItemAndTellsOutput() async throws {
        // Arrange
        let (sut, output, repository) = makeSUT()

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
        let (sut, _, repository) = makeSUT()

        // Act
        sut.save(makeDraft(name: "   Milk \n"), replacing: nil)

        // Assert
        XCTAssertEqual(try repository.fetchAll().first?.name, "Milk")
    }

    func test_save_withBlankName_isRejectedAndNothingIsSaved() async throws {
        // Arrange
        let (sut, output, repository) = makeSUT()

        // Act
        sut.save(makeDraft(name: "   "), replacing: nil)

        // Assert
        XCTAssertEqual(output.validationErrors, [.emptyName])
        XCTAssertEqual(output.saveCount, 0)
        XCTAssertTrue(try repository.fetchAll().isEmpty)
    }

    func test_save_withNameOverTheLimit_isRejected() async {
        // Arrange
        let (sut, output, _) = makeSUT()
        let tooLong = String(repeating: "a", count: PantryItemRules.maxNameLength + 1)

        // Act
        sut.save(makeDraft(name: tooLong), replacing: nil)

        // Assert
        XCTAssertEqual(output.validationErrors, [.nameTooLong(max: PantryItemRules.maxNameLength)])
    }

    func test_save_withNameExactlyAtTheLimit_isAccepted() async {
        // Arrange
        let (sut, output, _) = makeSUT()
        let atLimit = String(repeating: "a", count: PantryItemRules.maxNameLength)

        // Act
        sut.save(makeDraft(name: atLimit), replacing: nil)

        // Assert
        XCTAssertEqual(output.saveCount, 1)
    }

    func test_save_withQuantityOutsideTheRange_isRejected() async {
        // Arrange
        let (sut, output, _) = makeSUT()

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
        let (sut, _, _) = makeSUT(repository: repository)

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
        let (sut, output, _) = makeSUT(repository: FailingRepository())

        // Act
        sut.save(makeDraft(), replacing: nil)

        // Assert
        XCTAssertEqual(output.failureCount, 1)
        XCTAssertEqual(output.saveCount, 0)
    }
}
