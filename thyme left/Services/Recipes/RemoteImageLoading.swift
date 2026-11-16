import UIKit

/// A "job description" for fetching a picture from the internet.
@MainActor
protocol RemoteImageLoading: AnyObject {
    /// nil when the picture can't be fetched (offline, bad link, ...). Screens then show a placeholder.
    func image(for url: URL) async -> UIImage?
}

/// Downloads pictures and remembers them while the app runs, so scrolling back is instant.
@MainActor
final class URLSessionImageLoader: RemoteImageLoading {

    private let session: URLSession
    private let cache = NSCache<NSURL, UIImage>()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func image(for url: URL) async -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}

/// Never loads anything. Used by UI tests so they don't touch the internet.
@MainActor
final class NoImageLoader: RemoteImageLoading {
    func image(for url: URL) async -> UIImage? { nil }
}
