import Foundation
import ImageIO
import Vision

/// A "job description" for anything that can read text out of a picture.
/// (Translation: today it's Apple's Vision; tests can hand in a pretend reader.)
@MainActor
protocol TextRecognizing: AnyObject {
    /// Returns the text lines found in the picture, top to bottom.
    func recognizeLines(in imageData: Data) async throws -> [String]
}

enum TextRecognitionError: Error, Equatable {
    case unreadableImage
}

/// Reads text using Apple's built-in Vision framework (free, offline, private).
@MainActor
final class VisionTextRecognizer: TextRecognizing {

    func recognizeLines(in imageData: Data) async throws -> [String] {
        // Reading text is slow work, so we do it away from the main thread to keep the screen smooth.
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try Self.readLines(from: imageData))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    nonisolated private static func readLines(from data: Data) throws -> [String] {
        // Decode the picture upright and at a sensible size (phone photos can be huge and sideways).
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2400
              ] as CFDictionary) else {
            throw TextRecognitionError.unreadableImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false // dates aren't dictionary words, so don't "correct" them
        // Packs are often English AND Chinese, so read both (only the ones this iPhone supports).
        let supported = (try? request.supportedRecognitionLanguages()) ?? []
        let wanted = TextRecognitionLanguages.preferred.filter { supported.contains($0) }
        if !wanted.isEmpty { request.recognitionLanguages = wanted }

        try VNImageRequestHandler(cgImage: image).perform([request])
        let observations = request.results ?? []
        // Sort top-to-bottom (Vision's y axis starts at the bottom) so lines read like the pack does.
        return observations
            .sorted { $0.boundingBox.midY > $1.boundingBox.midY }
            .compactMap { $0.topCandidates(1).first?.string }
    }
}

/// A pretend reader that always "reads" the same lines. Used by UI tests so they don't depend on a real picture.
@MainActor
final class StubTextRecognizer: TextRecognizing {

    private let lines: [String]

    init(lines: [String]) {
        self.lines = lines
    }

    func recognizeLines(in imageData: Data) async throws -> [String] { lines }
}

/// Which languages the text readers should understand.
enum TextRecognitionLanguages {
    /// English first (most dates are digits and English labels), then Simplified Chinese.
    static let preferred = ["en-US", "zh-Hans"]
}
