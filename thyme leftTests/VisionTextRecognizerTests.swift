import XCTest
import UIKit
@testable import thyme_left

/// Runs the REAL Apple Vision text reader on pictures we draw in the test.
/// (Translation: this checks the whole chain - picture -> text -> date - not just the date maths.)
@MainActor
final class VisionTextRecognizerTests: XCTestCase {

    /// Draws white "pack" with black printed lines, like a label.
    private func makeLabel(_ lines: [String], fontSize: CGFloat = 64) -> Data {
        let size = CGSize(width: 1400, height: CGFloat(lines.count) * (fontSize * 1.8) + 120)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 1) { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            for (index, line) in lines.enumerated() {
                (line as NSString).draw(at: CGPoint(x: 60, y: 60 + CGFloat(index) * fontSize * 1.8), withAttributes: attributes)
            }
        }
    }

    private func scan(_ lines: [String], dayFirst: Bool = true) async throws -> ScannedExpiryDate? {
        let recognized = try await VisionTextRecognizer().recognizeLines(in: makeLabel(lines))
        let parser = ExpiryDateParser(calendar: TestCalendar.utc)
        return parser.parse(lines: recognized, dayFirst: dayFirst, now: TestCalendar.date(2026, 11, 15))
    }

    func test_recognizeLines_readsPrintedText() async throws {
        // Act
        let lines = try await VisionTextRecognizer().recognizeLines(in: makeLabel(["MILK", "BEST BEFORE 18 NOV 2026"]))

        // Assert
        let joined = lines.joined(separator: " ").uppercased()
        XCTAssertTrue(joined.contains("MILK"), "read: \(lines)")
        XCTAssertTrue(joined.contains("2026"), "read: \(lines)")
    }

    func test_recognizeLines_returnsLinesTopToBottom() async throws {
        // Act
        let lines = try await VisionTextRecognizer().recognizeLines(in: makeLabel(["APPLE", "BANANA", "CHERRY"]))

        // Assert
        let upper = lines.map { $0.uppercased() }
        let positions = ["APPLE", "BANANA", "CHERRY"].compactMap { word in upper.firstIndex { $0.contains(word) } }
        XCTAssertEqual(positions, positions.sorted())
        XCTAssertEqual(positions.count, 3, "read: \(lines)")
    }

    func test_wholeChain_findsADateOnAPrintedLabel() async throws {
        // Act
        let found = try await scan(["Organic Oat Drink", "NET 1 L", "BEST BEFORE 18/11/2026", "L2345"])

        // Assert
        XCTAssertEqual(found?.date, TestCalendar.date(2026, 11, 18))
    }

    func test_wholeChain_prefersTheExpiryOverTheManufactureDate() async throws {
        // Act
        let found = try await scan(["MFG 18/05/2026", "EXP 20/12/2026"])

        // Assert
        XCTAssertEqual(found?.date, TestCalendar.date(2026, 12, 20))
    }

    func test_wholeChain_readsMonthNamesAndNoDate() async throws {
        let named = try await scan(["USE BY 05 DEC 2026"])
        XCTAssertEqual(named?.date, TestCalendar.date(2026, 12, 5))

        let none = try await scan(["Ingredients: oats, water", "MAY CONTAIN NUTS"])
        XCTAssertNil(none)
    }

    func test_recognizeLines_withDataThatIsNotAPicture_throws() async {
        do {
            _ = try await VisionTextRecognizer().recognizeLines(in: Data("nope".utf8))
            XCTFail("should have thrown")
        } catch {
            XCTAssertEqual(error as? TextRecognitionError, .unreadableImage)
        }
    }
}
