import Foundation
import SwiftData

@Model
final class TrainingVideoPost {
    @Attribute(.unique) var id: String
    var playerID: String
    var objectKey: String
    var fileName: String
    var createdDay: Date
    var uploadedAt: Date
    var fileSize: Int64
    var remoteVideoURLString: String?
    var localThumbnailRelativePath: String?
    var durationSeconds: Double?
    var previewStatusRawValue: String

    var contentTypeRawValue: String
    var drillName: String?
    var note: String?
    var analysisStatusRawValue: String
    var latestAnalysisHeadline: String?
    var latestAnalysisSummary: String?
    var latestAnalysisFocus: String?
    var latestRecommendation: String?
    var latestAnalysisErrorMessage: String?
    var analysisModelName: String?
    var analysisUpdatedAt: Date?
    var baselineVideoPostID: String?

    init(
        id: String = UUID().uuidString,
        playerID: String,
        objectKey: String,
        fileName: String,
        createdDay: Date,
        uploadedAt: Date,
        fileSize: Int64,
        remoteVideoURLString: String? = nil,
        localThumbnailRelativePath: String? = nil,
        durationSeconds: Double? = nil,
        previewStatus: VideoPreviewStatus = .pending,
        contentType: TrainingVideoContentType = .training,
        drillName: String? = nil,
        note: String? = nil,
        analysisStatus: VideoAnalysisStatus = .idle,
        latestAnalysisHeadline: String? = nil,
        latestAnalysisSummary: String? = nil,
        latestAnalysisFocus: String? = nil,
        latestRecommendation: String? = nil,
        latestAnalysisErrorMessage: String? = nil,
        analysisModelName: String? = nil,
        analysisUpdatedAt: Date? = nil,
        baselineVideoPostID: String? = nil
    ) {
        self.id = id
        self.playerID = playerID
        self.objectKey = objectKey
        self.fileName = fileName
        self.createdDay = Self.normalizedDay(for: createdDay)
        self.uploadedAt = uploadedAt
        self.fileSize = fileSize
        self.remoteVideoURLString = remoteVideoURLString
        self.localThumbnailRelativePath = localThumbnailRelativePath
        self.durationSeconds = durationSeconds
        self.previewStatusRawValue = previewStatus.rawValue
        self.contentTypeRawValue = contentType.rawValue
        self.drillName = drillName
        self.note = note
        self.analysisStatusRawValue = analysisStatus.rawValue
        self.latestAnalysisHeadline = latestAnalysisHeadline
        self.latestAnalysisSummary = latestAnalysisSummary
        self.latestAnalysisFocus = latestAnalysisFocus
        self.latestRecommendation = latestRecommendation
        self.latestAnalysisErrorMessage = latestAnalysisErrorMessage
        self.analysisModelName = analysisModelName
        self.analysisUpdatedAt = analysisUpdatedAt
        self.baselineVideoPostID = baselineVideoPostID
    }

    var contentType: TrainingVideoContentType {
        get { TrainingVideoContentType(rawValue: contentTypeRawValue) ?? .training }
        set { contentTypeRawValue = newValue.rawValue }
    }

    var analysisStatus: VideoAnalysisStatus {
        get { VideoAnalysisStatus(rawValue: analysisStatusRawValue) ?? .idle }
        set { analysisStatusRawValue = newValue.rawValue }
    }

    var previewStatus: VideoPreviewStatus {
        get { VideoPreviewStatus(rawValue: previewStatusRawValue) ?? .pending }
        set { previewStatusRawValue = newValue.rawValue }
    }

    var remoteVideoURL: URL? {
        guard let remoteVideoURLString else { return nil }
        return URL(string: remoteVideoURLString)
    }

    var localThumbnailURL: URL? {
        guard let localThumbnailRelativePath else { return nil }
        return Self.previewBaseDirectory.appendingPathComponent(localThumbnailRelativePath)
    }

    var displayAnalysisHeadline: String? {
        if let latestAnalysisHeadline, !latestAnalysisHeadline.isEmpty {
            return latestAnalysisHeadline
        }

        return nil
    }

    var latestAnalysisFocusPoints: [String] {
        guard let latestAnalysisFocus, !latestAnalysisFocus.isEmpty else { return [] }

        return latestAnalysisFocus
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmed }
            .filter { !$0.isEmpty }
    }

    /// 删除本地缓存文件（缩略图），不删除远程 OSS 对象
    func deleteLocalFiles() {
        if let localThumbnailURL {
            try? FileManager.default.removeItem(at: localThumbnailURL)
        }
    }

    static func normalizedDay(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> Date {
        calendar.startOfDay(for: date)
    }

    static var previewBaseDirectory: URL {
        let fileManager = FileManager.default
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return cachesDirectory.appendingPathComponent("VideoPreviews", isDirectory: true)
    }

    static func fromLegacyRecord(_ record: UploadedTrainingVideoRecord) -> TrainingVideoPost {
        TrainingVideoPost(
            id: record.id,
            playerID: record.playerID,
            objectKey: record.objectKey,
            fileName: record.fileName,
            createdDay: record.trainingDate,
            uploadedAt: record.uploadedAt,
            fileSize: record.fileSize,
            previewStatus: .failed,
            contentType: .training,
            analysisStatus: .idle
        )
    }
}
