import AlibabaCloudOSS
import Foundation
import UniformTypeIdentifiers

actor OSSUploadService {
    private let configuration: OSSConfiguration
    private let client: Client

    /// Files larger than this threshold use multipart upload.
    private let multipartThreshold = 10 * 1024 * 1024 // 10 MB
    /// Each part size for multipart upload.
    private let partSize = 5 * 1024 * 1024 // 5 MB

    init(configuration: OSSConfiguration? = nil) throws {
        let resolvedConfiguration = try configuration ?? OSSConfiguration.load()
        self.configuration = resolvedConfiguration

        let credentialsProvider = StaticCredentialsProvider(
            accessKeyId: resolvedConfiguration.accessKeyID,
            accessKeySecret: resolvedConfiguration.accessKeySecret
        )
        let clientConfiguration = Configuration.default()
            .withRegion(resolvedConfiguration.region)
            .withEndpoint(resolvedConfiguration.endpoint)
            .withCredentialsProvider(credentialsProvider)
            .withTimeoutIntervalForRequest(60)
            .withTimeoutIntervalForResource(3600)
            .withRetryMaxAttempts(3)

        client = Client(clientConfiguration)
    }

    func uploadTrainingVideo(
        fileURL: URL,
        userID: String,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> UploadedTrainingVideo {
        let uploadedAt = Date()
        let createdDay = TrainingVideoPost.normalizedDay(for: uploadedAt)
        let objectKey = objectKey(for: fileURL, userID: userID, createdDay: createdDay)
        let fileSize = try fileSize(for: fileURL)
        let contentType = Self.contentType(for: fileURL)

        if fileSize <= Int64(multipartThreshold) {
            try await simplePutUpload(
                fileURL: fileURL,
                objectKey: objectKey,
                contentType: contentType,
                progressHandler: progressHandler
            )
        } else {
            try await multipartUpload(
                fileURL: fileURL,
                fileSize: fileSize,
                objectKey: objectKey,
                contentType: contentType,
                progressHandler: progressHandler
            )
        }

        progressHandler?(1)

        return UploadedTrainingVideo(
            bucket: configuration.bucket,
            objectKey: objectKey,
            remoteURL: publicURL(for: objectKey),
            fileSize: fileSize,
            uploadedAt: uploadedAt,
            createdDay: createdDay
        )
    }

    // MARK: - Simple Upload

    private func simplePutUpload(
        fileURL: URL,
        objectKey: String,
        contentType: String,
        progressHandler: (@Sendable (Double) -> Void)?
    ) async throws {
        // File-backed uploads can drop the connection (-1005) on this SDK path.
        // Small files stay under the 10 MB threshold, so buffering in memory is acceptable here.
        let bodyData = try Data(contentsOf: fileURL)

        try await retryOnTransientError {
            var request = PutObjectRequest(
                bucket: self.configuration.bucket,
                key: objectKey,
                contentType: contentType,
                body: .data(bodyData)
            )
            request.progress = ProgressClosure { _, totalBytesTransferred, totalBytesExpected in
                guard totalBytesExpected > 0 else { return }
                let progress = Double(totalBytesTransferred) / Double(totalBytesExpected)
                progressHandler?(progress)
            }
            _ = try await self.client.putObject(request)
        }
    }

    // MARK: - Multipart Upload

    private func multipartUpload(
        fileURL: URL,
        fileSize: Int64,
        objectKey: String,
        contentType: String,
        progressHandler: (@Sendable (Double) -> Void)?
    ) async throws {
        let initResult = try await client.initiateMultipartUpload(
            InitiateMultipartUploadRequest(
                bucket: configuration.bucket,
                key: objectKey,
                contentType: contentType
            )
        )
        guard let uploadId = initResult.uploadId else {
            throw OSSUploadError.unknown
        }

        var succeeded = false
        defer {
            if !succeeded {
                Task { [client, configuration] in
                    try? await client.abortMultipartUpload(
                        AbortMultipartUploadRequest(
                            bucket: configuration.bucket,
                            key: objectKey,
                            uploadId: uploadId
                        )
                    )
                }
            }
        }

        var partCount = Int(fileSize / Int64(partSize))
        if fileSize % Int64(partSize) > 0 { partCount += 1 }

        guard let fileHandle = FileHandle(forReadingAtPath: fileURL.path) else {
            throw OSSUploadError.unknown
        }
        defer { try? fileHandle.close() }

        var parts: [UploadPart] = []

        for partNumber in 1...partCount {
            fileHandle.seek(toFileOffset: UInt64((partNumber - 1) * partSize))
            let data = fileHandle.readData(ofLength: partSize)

            let uploadPartResult: UploadPartResult = try await retryOnTransientError {
                try await self.client.uploadPart(
                    UploadPartRequest(
                        bucket: self.configuration.bucket,
                        key: objectKey,
                        partNumber: partNumber,
                        uploadId: uploadId,
                        body: .data(data)
                    )
                )
            }

            parts.append(UploadPart(etag: uploadPartResult.etag, partNumber: partNumber))
            progressHandler?(Double(partNumber) / Double(partCount))
        }

        _ = try await client.completeMultipartUpload(
            CompleteMultipartUploadRequest(
                bucket: configuration.bucket,
                key: objectKey,
                uploadId: uploadId,
                completeMultipartUpload: CompleteMultipartUpload(parts: parts)
            )
        )

        succeeded = true
    }

    func playbackURL(for objectKey: String, expirationInterval: TimeInterval = 15 * 60) async throws -> URL {
        let request = GetObjectRequest(bucket: configuration.bucket, key: objectKey)
        let expiration = Date().addingTimeInterval(expirationInterval)
        let result = try await client.presign(request, expiration)

        guard let url = URL(string: result.url) else {
            throw OSSPlaybackURLError.invalidPresignedURL
        }

        return url
    }

    private func retryOnTransientError<T: Sendable>(
        maxAttempts: Int = 3,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                guard isTransientNetworkError(error),
                      attempt < maxAttempts - 1 else {
                    throw error
                }

                let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                try await Task.sleep(nanoseconds: delay)
            }
        }

        throw lastError ?? OSSUploadError.unknown
    }

    private static let retryableURLErrorCodes: Set<Int> = [-1001, -1004, -1005, -1009]

    private func isTransientNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain,
           Self.retryableURLErrorCodes.contains(nsError.code) {
            return true
        }
        if let clientError = error as? ClientError,
           let inner = clientError.innerError {
            return isTransientNetworkError(inner)
        }
        return false
    }

    private func objectKey(for fileURL: URL, userID: String, createdDay: Date) -> String {
        let sanitizedUserID = sanitizedPathComponent(userID)
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: createdDay)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        let fileExtension = fileURL.pathExtension.isEmpty ? "mov" : fileURL.pathExtension.lowercased()

        return "\(configuration.uploadDirectory)/\(sanitizedUserID)/\(year)/\(String(format: "%02d", month))/\(String(format: "%02d", day))/\(UUID().uuidString).\(fileExtension)"
    }

    private func sanitizedPathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let filtered = value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let result = String(filtered)
            .replacingOccurrences(of: "--", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return result.isEmpty ? "anonymous" : result
    }

    private static func contentType(for fileURL: URL) -> String {
        if let type = UTType(filenameExtension: fileURL.pathExtension),
           let preferredMIMEType = type.preferredMIMEType {
            return preferredMIMEType
        }

        return "video/quicktime"
    }

    private func publicURL(for objectKey: String) -> URL? {
        if let publicBaseURL = configuration.publicBaseURL?.trimmed, !publicBaseURL.isEmpty {
            return URL(string: publicBaseURL.appendingPathComponentIfNeeded(objectKey))
        }

        var endpoint = configuration.endpoint
        if !endpoint.contains("://") {
            endpoint = "https://\(endpoint)"
        }

        guard let endpointURL = URL(string: endpoint),
              let host = endpointURL.host else {
            return nil
        }

        return URL(string: "\(endpointURL.scheme ?? "https")://\(configuration.bucket).\(host)/\(objectKey)")
    }

    private func fileSize(for fileURL: URL) throws -> Int64 {
        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values.fileSize ?? 0)
    }
}

struct UploadedTrainingVideo: Equatable, Sendable {
    let bucket: String
    let objectKey: String
    let remoteURL: URL?
    let fileSize: Int64
    let uploadedAt: Date
    let createdDay: Date
}

enum OSSUploadError: LocalizedError {
    case fileTooLarge(maxSizeInMegabytes: Int)
    case unsupportedFileType
    case unknown

    var errorDescription: String? {
        switch self {
        case .fileTooLarge(let maxSizeInMegabytes):
            "视频过大，请选择小于 \(maxSizeInMegabytes) MB 的文件。"
        case .unsupportedFileType:
            "暂不支持该视频格式，请选择 MOV 或 MP4 文件。"
        case .unknown:
            "上传失败，请稍后重试。"
        }
    }
}

enum OSSPlaybackURLError: LocalizedError {
    case invalidPresignedURL

    var errorDescription: String? {
        switch self {
        case .invalidPresignedURL:
            "视频播放地址生成失败，请稍后重试。"
        }
    }
}

private extension String {
    func appendingPathComponentIfNeeded(_ component: String) -> String {
        hasSuffix("/") ? self + component : self + "/" + component
    }
}
