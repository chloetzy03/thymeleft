import XCTest
import UIKit
@testable import thyme_left

@MainActor
final class JPEGThumbnailerTests: XCTestCase {

    // MARK: Helpers

    /// Makes a plain coloured picture of the given size (1 point = 1 pixel).
    private func makePicture(width: Int, height: Int, orientation: UIImage.Orientation = .up) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        guard orientation != .up, let cgImage = image.cgImage else { return image.jpegData(compressionQuality: 1)! }
        return UIImage(cgImage: cgImage, scale: 1, orientation: orientation).jpegData(compressionQuality: 1)!
    }

    private func size(of data: Data) -> CGSize? {
        UIImage(data: data).map { CGSize(width: $0.size.width * $0.scale, height: $0.size.height * $0.scale) }
    }

    // MARK: Tests

    func test_make_shrinksALargePictureKeepingItsShape() async throws {
        // Arrange
        let big = makePicture(width: 2000, height: 1000)

        // Act
        let result = try XCTUnwrap(JPEGThumbnailer.make(from: big, maxPixelSize: 600))

        // Assert
        let newSize = try XCTUnwrap(size(of: result))
        XCTAssertEqual(newSize.width, 600, accuracy: 1)
        XCTAssertEqual(newSize.height, 300, accuracy: 1)
        XCTAssertLessThan(result.count, big.count)
    }

    func test_make_neverEnlargesASmallPicture() async throws {
        // Arrange
        let small = makePicture(width: 100, height: 50)

        // Act
        let result = try XCTUnwrap(JPEGThumbnailer.make(from: small, maxPixelSize: 600))

        // Assert
        let newSize = try XCTUnwrap(size(of: result))
        XCTAssertEqual(newSize.width, 100, accuracy: 1)
        XCTAssertEqual(newSize.height, 50, accuracy: 1)
    }

    func test_make_producesAJPEGFile() async throws {
        // Arrange
        let picture = makePicture(width: 300, height: 300)

        // Act
        let result = try XCTUnwrap(JPEGThumbnailer.make(from: picture, maxPixelSize: 600))

        // Assert: every JPEG file starts with the bytes FF D8
        XCTAssertEqual(Array(result.prefix(2)), [0xFF, 0xD8])
    }

    func test_make_turnsASidewaysPhotoUpright() async throws {
        // Arrange: a 400x200 picture flagged "rotated right", as phones do when held sideways
        let sideways = makePicture(width: 400, height: 200, orientation: .right)

        // Act
        let result = try XCTUnwrap(JPEGThumbnailer.make(from: sideways, maxPixelSize: 600))

        // Assert: it now really is tall (200 wide, 400 high)
        let newSize = try XCTUnwrap(size(of: result))
        XCTAssertEqual(newSize.width, 200, accuracy: 1)
        XCTAssertEqual(newSize.height, 400, accuracy: 1)
    }

    func test_make_withDataThatIsNotAPicture_returnsNil() async {
        // Arrange
        let garbage = Data("definitely not an image".utf8)

        // Act
        let result = JPEGThumbnailer.make(from: garbage, maxPixelSize: 600)

        // Assert
        XCTAssertNil(result)
    }
}

@MainActor
final class FileSystemPhotoStoreTests: XCTestCase {

    private var folder: URL!

    override func setUp() async throws {
        try await super.setUp()
        // A private, throw-away folder so tests never touch the app's real photos.
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("thyme-left-tests-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: folder)
        try await super.tearDown()
    }

    private func makePicture(width: Int = 800, height: Int = 600) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
            .jpegData(withCompressionQuality: 1) { context in
                UIColor.systemOrange.setFill()
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            }
    }

    func test_savePhoto_thenPhotoData_returnsAShrunkPicture() async throws {
        // Arrange
        let sut = FileSystemPhotoStore(directory: folder, maxPixelSize: 400)

        // Act
        let name = try sut.savePhoto(makePicture(width: 800, height: 600))

        // Assert
        XCTAssertTrue(name.hasSuffix(".jpg"))
        let stored = try XCTUnwrap(sut.photoData(named: name))
        let image = try XCTUnwrap(UIImage(data: stored))
        XCTAssertEqual(image.size.width, 400, accuracy: 1)
        XCTAssertEqual(image.size.height, 300, accuracy: 1)
    }

    func test_savePhoto_givesEverySaveItsOwnName() async throws {
        // Arrange
        let sut = FileSystemPhotoStore(directory: folder)
        let picture = makePicture()

        // Act
        let first = try sut.savePhoto(picture)
        let second = try sut.savePhoto(picture)

        // Assert
        XCTAssertNotEqual(first, second)
    }

    func test_deletePhoto_removesTheFile() async throws {
        // Arrange
        let sut = FileSystemPhotoStore(directory: folder)
        let name = try sut.savePhoto(makePicture())

        // Act
        sut.deletePhoto(named: name)

        // Assert
        XCTAssertNil(sut.photoData(named: name))
    }

    func test_deletePhoto_whenThereIsNoSuchFile_doesNothingBad() async {
        // Arrange
        let sut = FileSystemPhotoStore(directory: folder)

        // Act + Assert (must not crash or throw)
        sut.deletePhoto(named: "never-existed.jpg")
    }

    func test_savePhoto_withDataThatIsNotAPicture_throws() async {
        // Arrange
        let sut = FileSystemPhotoStore(directory: folder)

        // Act + Assert
        XCTAssertThrowsError(try sut.savePhoto(Data("nope".utf8))) { error in
            XCTAssertEqual(error as? PhotoStoreError, .unreadableImage)
        }
    }

    func test_photoData_cannotReadFilesOutsideThePhotosFolder() async throws {
        // Arrange: a "secret" file next to (not inside) the photos folder
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let photosFolder = folder.appendingPathComponent("Photos")
        try Data("secret".utf8).write(to: folder.appendingPathComponent("secret.jpg"))
        let sut = FileSystemPhotoStore(directory: photosFolder)

        // Act
        let leaked = sut.photoData(named: "../secret.jpg")

        // Assert
        XCTAssertNil(leaked)
    }
}
