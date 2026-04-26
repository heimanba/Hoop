import AVFoundation
import CoreGraphics
import Foundation
import UIKit

struct VideoPreview {
    let relativeThumbnailPath: String
    let durationSeconds: Double
}

actor VideoPreviewService {
    func makePreview(for fileURL: URL, postID: String) async throws -> VideoPreview {
        let asset = AVURLAsset(url: fileURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = max(CMTimeGetSeconds(duration), 0)

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1200, height: 1200)

        let frameTime = previewTime(for: durationSeconds)
        let image = try generator.copyCGImage(at: frameTime, actualTime: nil)
        let relativePath = "\(postID).jpg"
        let outputURL = TrainingVideoPost.previewBaseDirectory.appendingPathComponent(relativePath)

        try persistThumbnail(image, to: outputURL)

        return VideoPreview(
            relativeThumbnailPath: relativePath,
            durationSeconds: durationSeconds
        )
    }

    private func previewTime(for durationSeconds: Double) -> CMTime {
        guard durationSeconds.isFinite, durationSeconds > 0 else {
            return CMTime(seconds: 0, preferredTimescale: 600)
        }

        return CMTime(seconds: min(durationSeconds * 0.15, 0.2), preferredTimescale: 600)
    }

    private func persistThumbnail(_ image: CGImage, to outputURL: URL) throws {
        let directory = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let uiImage = UIImage(cgImage: image)
        guard let data = uiImage.jpegData(compressionQuality: 0.82) else {
            throw PreviewGenerationError.encodingFailed
        }

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        try data.write(to: outputURL, options: .atomic)
    }
}

enum PreviewGenerationError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            "视频首图生成失败。"
        }
    }
}
