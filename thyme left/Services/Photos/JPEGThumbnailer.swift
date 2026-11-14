import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Shrinks a big photo into a small, tidy JPEG.
/// (Translation: a phone photo can be 5 MB. We only need a small picture to recognise the
/// food, so we shrink it to about 600 pixels wide, which is tiny but still sharp on screen.)
enum JPEGThumbnailer {

    /// Returns nil if `data` isn't a readable picture.
    static func make(from data: Data, maxPixelSize: Int, quality: Double = 0.8) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        // Never make a small picture bigger: cap at the original's longest side.
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? maxPixelSize
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? maxPixelSize
        let longestSide = min(maxPixelSize, max(width, height))

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true, // turns sideways phone photos upright
            kCGImageSourceThumbnailMaxPixelSize: longestSide,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image,
                                   [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
