import Foundation

/// A "job description" for anything that can keep item photos.
/// (Translation: the app says "save this picture, give me back a name, and later hand me the
/// picture for that name". Where the files really live is this service's secret.)
@MainActor
protocol PhotoStoring: AnyObject {
    /// Shrinks and saves the picture, then returns the file name to remember it by.
    func savePhoto(_ imageData: Data) throws -> String
    func photoData(named fileName: String) -> Data?
    /// Deleting a photo that doesn't exist is fine (nothing to do).
    func deletePhoto(named fileName: String)
}

enum PhotoStoreError: Error, Equatable {
    case unreadableImage
    case couldNotWrite
}

/// Keeps photos as small JPEG files in the app's private folder on the phone.
@MainActor
final class FileSystemPhotoStore: PhotoStoring {

    private let directory: URL
    private let maxPixelSize: Int
    private let fileManager: FileManager

    /// Pass a `directory` to keep photos somewhere else (tests use a throw-away folder).
    init(directory: URL? = nil,
         maxPixelSize: Int = 600,
         fileManager: FileManager = .default) {
        self.directory = directory ?? Self.defaultDirectory
        self.maxPixelSize = maxPixelSize
        self.fileManager = fileManager
    }

    /// ".../Application Support/Photos", private to this app.
    static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Photos", isDirectory: true)
    }

    func savePhoto(_ imageData: Data) throws -> String {
        guard let jpeg = JPEGThumbnailer.make(from: imageData, maxPixelSize: maxPixelSize) else {
            throw PhotoStoreError.unreadableImage
        }
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let fileName = "\(UUID().uuidString).jpg" // a fresh name every time, so old copies never get mixed up
            try jpeg.write(to: directory.appendingPathComponent(fileName), options: .atomic)
            return fileName
        } catch {
            throw PhotoStoreError.couldNotWrite
        }
    }

    func photoData(named fileName: String) -> Data? {
        try? Data(contentsOf: url(for: fileName))
    }

    func deletePhoto(named fileName: String) {
        try? fileManager.removeItem(at: url(for: fileName))
    }

    /// `lastPathComponent` keeps a damaged name like "../../x" from escaping the Photos folder.
    private func url(for fileName: String) -> URL {
        directory.appendingPathComponent((fileName as NSString).lastPathComponent)
    }
}

/// Keeps photos in memory only. Used by tests and UI tests.
@MainActor
final class InMemoryPhotoStore: PhotoStoring {

    private(set) var photos: [String: Data] = [:]
    var shouldFailToSave = false

    func savePhoto(_ imageData: Data) throws -> String {
        if shouldFailToSave { throw PhotoStoreError.couldNotWrite }
        let fileName = "\(UUID().uuidString).jpg"
        photos[fileName] = imageData
        return fileName
    }

    func photoData(named fileName: String) -> Data? { photos[fileName] }
    func deletePhoto(named fileName: String) { photos[fileName] = nil }
}
