import AlibabaCloudOSS
import Foundation
import OSLog
import SwiftData

@MainActor
@Observable
final class TrainingUploadViewModel {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Hoop",
        category: "Upload"
    )

    private(set) var isUploading = false
    private(set) var progress: Double = 0
    private(set) var statusMessage: String?
    private(set) var uploadedVideo: UploadedTrainingVideo?
    private(set) var lastUploadedContentType: TrainingVideoContentType?
    var alertMessage: String?

    private let maximumFileSizeInMegabytes = 500
    private let previewService = VideoPreviewService()

    func uploadVideo(
        from fileURL: URL,
        userID: String,
        contentType: TrainingVideoContentType,
        context: ModelContext
    ) async {
        isUploading = true
        progress = 0
        statusMessage = "正在准备上传..."
        alertMessage = nil
        uploadedVideo = nil
        lastUploadedContentType = nil

        defer {
            isUploading = false
            try? FileManager.default.removeItem(at: fileURL)
        }

        do {
            try validateFile(at: fileURL)
            statusMessage = "正在上传\(contentType.title)视频..."

            let service = try OSSUploadService()
            let result = try await service.uploadTrainingVideo(fileURL: fileURL, userID: userID) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.progress = progress
                    self?.statusMessage = "上传中 \(Int(progress * 100))%"
                }
            }

            statusMessage = "正在生成视频首图..."
            try await saveVideoPost(
                for: result,
                originalFileURL: fileURL,
                userID: userID,
                contentType: contentType,
                in: context
            )
            uploadedVideo = result
            lastUploadedContentType = contentType
            progress = 1
            statusMessage = "视频已上传到 OSS"

            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(2))
                self?.statusMessage = nil
            }
        } catch {
            statusMessage = nil
            alertMessage = Self.safeMessage(for: error)
        }
    }

    func handleSelectionFailure(_ error: Error? = nil) {
        statusMessage = nil
        alertMessage = Self.safeMessage(for: error)
    }

    func clearAlert() {
        alertMessage = nil
    }

    private func validateFile(at fileURL: URL) throws {
        let allowedExtensions = Set(["mov", "mp4", "m4v"])
        let fileExtension = fileURL.pathExtension.lowercased()
        guard allowedExtensions.contains(fileExtension) else {
            throw OSSUploadError.unsupportedFileType
        }

        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        let fileSize = values.fileSize ?? 0
        let maximumSize = maximumFileSizeInMegabytes * 1024 * 1024
        guard fileSize <= maximumSize else {
            throw OSSUploadError.fileTooLarge(maxSizeInMegabytes: maximumFileSizeInMegabytes)
        }
    }

    private func saveVideoPost(
        for uploadedVideo: UploadedTrainingVideo,
        originalFileURL: URL,
        userID: String,
        contentType: TrainingVideoContentType,
        in context: ModelContext
    ) async throws {
        let postID = UUID().uuidString
        var localThumbnailRelativePath: String?
        var durationSeconds: Double?
        var previewStatus: VideoPreviewStatus = .pending

        do {
            let preview = try await previewService.makePreview(for: originalFileURL, postID: postID)
            localThumbnailRelativePath = preview.relativeThumbnailPath
            durationSeconds = preview.durationSeconds
            previewStatus = .ready
        } catch {
            previewStatus = .failed
        }

        let post = TrainingVideoPost(
            id: postID,
            playerID: userID,
            objectKey: uploadedVideo.objectKey,
            fileName: originalFileURL.lastPathComponent,
            createdDay: uploadedVideo.createdDay,
            uploadedAt: uploadedVideo.uploadedAt,
            fileSize: uploadedVideo.fileSize,
            remoteVideoURLString: uploadedVideo.remoteURL?.absoluteString,
            localThumbnailRelativePath: localThumbnailRelativePath,
            durationSeconds: durationSeconds,
            previewStatus: previewStatus,
            contentType: contentType,
            analysisStatus: .idle
        )

        context.insert(post)
        try context.save()
    }

    private static func safeMessage(for error: Error?) -> String {
        guard let error else {
            return "未能读取视频文件，请重试。"
        }

        logUploadError(error)

        if let serverError = unwrapServerError(from: error) {
            return safeMessage(for: serverError)
        }

        if let clientError = error as? ClientError {
            if clientError.code == "OperationError",
               let inner = clientError.innerError as NSError?,
               inner.domain == NSURLErrorDomain {
                return "网络不稳定，上传失败，请检查网络后重试。"
            }

            return safeMessage(for: clientError)
        }

        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            return description
        }

        let text = error.localizedDescription
        return text.isEmpty ? "出错了，请重试。" : text
    }

    private static func safeMessage(for clientError: ClientError) -> String {
        switch clientError.code {
        case "CredentialsError", "CredentialsFetchError":
            return "上传凭证无效，请检查 OSS AccessKey 配置。"
        case "ValidationError":
            if clientError.message.contains("Endpoint is invalid") {
                return "上传服务地址无效，请检查 OSS_ENDPOINT 配置。"
            }
            return "上传配置无效，请检查 OSS 配置。"
        case "ParameterError":
            return "上传请求参数无效，请检查 OSS 配置。"
        case "SerdeError":
            return "上传服务响应异常，请稍后重试。"
        default:
            let message = clientError.message.trimmed
            return message.isEmpty || clientError.code == "OperationError"
                ? "上传服务异常，请稍后重试。"
                : "上传失败：\(message)"
        }
    }

    private static func safeMessage(for serverError: ServerError) -> String {
        switch serverError.code {
        case "AccessDenied":
            return "上传失败：OSS 拒绝访问，请检查 AccessKey 和 Bucket 权限。"
        case "InvalidAccessKeyId", "SignatureDoesNotMatch":
            return "上传失败：OSS 凭证校验失败，请检查 AccessKey 配置。"
        case "NoSuchBucket":
            return "上传失败：目标 Bucket 不存在，请检查 OSS_BUCKET 配置。"
        case "AuthorizationHeaderMalformed":
            return "上传失败：OSS 区域配置不匹配，请检查 OSS_REGION 和 OSS_ENDPOINT。"
        case "RequestTimeTooSkewed":
            return "上传失败：设备时间异常，请校准系统时间后重试。"
        default:
            let message = serverError.message.trimmed
            if !message.isEmpty {
                return "上传失败：\(message)"
            }

            let code = serverError.code.trimmed
            return code.isEmpty ? "上传服务异常，请稍后重试。" : "上传失败：\(code)"
        }
    }

    private static func unwrapServerError(from error: Error) -> ServerError? {
        if let serverError = error as? ServerError {
            return serverError
        }

        if let clientError = error as? ClientError,
           let innerError = clientError.innerError {
            return unwrapServerError(from: innerError)
        }

        return nil
    }

    private static func logUploadError(_ error: Error) {
        if let serverError = unwrapServerError(from: error) {
            logger.error(
                """
                OSS upload failed. status=\(serverError.statusCode, privacy: .public) \
                code=\(serverError.code, privacy: .public) \
                requestId=\(serverError.requestId, privacy: .public) \
                message=\(serverError.message, privacy: .public)
                """
            )
            return
        }

        if let clientError = error as? ClientError {
            let inner = clientError.innerError.map(String.init(describing:)) ?? "nil"
            logger.error(
                """
                OSS upload failed. clientCode=\(clientError.code, privacy: .public) \
                message=\(clientError.message, privacy: .public) \
                inner=\(inner, privacy: .public)
                """
            )
            return
        }

        logger.error("Upload failed. error=\(String(describing: error), privacy: .public)")
    }
}
