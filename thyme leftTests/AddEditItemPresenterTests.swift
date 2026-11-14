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

        func showForm(_ form: AddEditFormViewModel) { self.form = form }
        func showEmoji(_ emoji: String) { self.emoji = emoji }
        func showExpiryDate(_ date: Date) { expiryDate = date }
        func showNameError(_ message: String?) { nameError = message }
        func showError(message: String) { errorMessage = message }
    }

    private final class InteractorSpy: AddEditItemInteractorInput {
        var savedDrafts: [PantryItemDraft] = []
        var replaced: [PantryItem?] = []

        func save(_ draft: PantryItemDraft, replacing existing: PantryItem?) {
            savedDrafts.append(draft)
            replaced.append(existing)
        }
    }

    private final class RouterSpy: AddEditItemRouterProtocol {
        var closeCount = 0
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

    private func makeSUT(existing: PantryItem? = nil, onSaved: @escaping () -> Void = {})
        -> (sut: AddEditItemPresenter, view: ViewSpy, interactor: InteractorSpy, router: RouterSpy) {
        let view = ViewSpy()
        let interactor = InteractorSpy()
        let router = RouterSpy()
        let sut = AddEditItemPresenter(view: view, interactor: interactor, router: router,
                                       iconProvider: EmojiFoodIconProvider(),
                                       dateProvider: FixedDateProvider(now: today),
                                       existingItem: existing, calendar: calendar, onSaved: onSaved)
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

        // Act
        sut.didTapSave(name: "Milk", quantity: 2, locationIndex: 3, expiryDate: today)

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

        // Act
        sut.didTapSave(name: "Oat milk", quantity: 1, locationIndex: 0, expiryDate: today)

        // Assert
        XCTAssertEqual(interactor.replaced.first??.id, item.id)
    }

    func test_didTapSave_withInvalidLocationIndex_doesNothing() async {
        // Arrange
        let (sut, _, interactor, _) = makeSUT()

        // Act
        sut.didTapSave(name: "Milk", quantity: 1, locationIndex: 99, expiryDate: today)

        // Assert
        XCTAssertTrue(interactor.savedDrafts.isEmpty)
    }

    func test_didSave_notifiesThePreviousScreenAndCloses() async {
        // Arrange
        var savedCallbackCount = 0
        let (sut, _, _, router) = makeSUT(onSaved: { savedCallbackCount += 1 })

        // Act
        sut.didSave()

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
}
