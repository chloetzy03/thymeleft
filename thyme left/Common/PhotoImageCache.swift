import UIKit

/// Hands out ready-to-draw pictures for photo file names, remembering the ones it already loaded.
/// (Translation: while you scroll the list, each photo is read from disk only once.)
@MainActor
final class PhotoImageCache {

    private let photoStore: PhotoStoring
    private let cache = NSCache<NSString, UIImage>()

    init(photoStore: PhotoStoring) {
        self.photoStore = photoStore
    }

    func image(named fileName: String) -> UIImage? {
        if let cached = cache.object(forKey: fileName as NSString) { return cached }
        guard let data = photoStore.photoData(named: fileName),
              let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: fileName as NSString)
        return image
    }
}
