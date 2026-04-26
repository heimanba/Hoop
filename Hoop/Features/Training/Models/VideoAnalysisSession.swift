import Foundation
import SwiftData

enum VideoAnalysisSessionStatus: String, Codable {
    case idle
    case generatingInitialMessage
    case ready
    case replying
    case failed
    case archived

    var title: String {
        switch self {
        case .idle:
            "待开始"
        case .generatingInitialMessage:
            "分析中"
        case .ready:
            "会话中"
        case .replying:
            "回复中"
        case .failed:
            "失败"
        case .archived:
            "历史"
        }
    }
}

@Model
final class VideoAnalysisSession {
    @Attribute(.unique) var id: String
    var videoID: String
    var selectedTagRawValue: String
    var sessionStatusRawValue: String
    var startedAt: Date
    var completedAt: Date?
    var failedAt: Date?
    var modelName: String?
    var initialAnalysisMessageID: String?
    var lastMessageAt: Date?
    var lastErrorMessage: String?
    var recommendedQuestionsRawValue: String?

    init(
        id: String = UUID().uuidString,
        videoID: String,
        selectedTag: VideoAnalysisTag,
        sessionStatus: VideoAnalysisSessionStatus = .idle,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        failedAt: Date? = nil,
        modelName: String? = nil,
        initialAnalysisMessageID: String? = nil,
        lastMessageAt: Date? = nil,
        lastErrorMessage: String? = nil,
        recommendedQuestions: [String] = []
    ) {
        self.id = id
        self.videoID = videoID
        self.selectedTagRawValue = selectedTag.rawValue
        self.sessionStatusRawValue = sessionStatus.rawValue
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.failedAt = failedAt
        self.modelName = modelName
        self.initialAnalysisMessageID = initialAnalysisMessageID
        self.lastMessageAt = lastMessageAt
        self.lastErrorMessage = lastErrorMessage
        self.recommendedQuestionsRawValue = recommendedQuestions.joined(separator: "\n")
    }

    var selectedTag: VideoAnalysisTag {
        get { VideoAnalysisTag(rawValue: selectedTagRawValue) ?? .trainingForm }
        set { selectedTagRawValue = newValue.rawValue }
    }

    var sessionStatus: VideoAnalysisSessionStatus {
        get { VideoAnalysisSessionStatus(rawValue: sessionStatusRawValue) ?? .idle }
        set { sessionStatusRawValue = newValue.rawValue }
    }

    var recommendedQuestions: [String] {
        get {
            guard let recommendedQuestionsRawValue, !recommendedQuestionsRawValue.isEmpty else { return [] }
            return recommendedQuestionsRawValue
                .split(whereSeparator: \.isNewline)
                .map { String($0).trimmed }
                .filter { !$0.isEmpty }
        }
        set {
            recommendedQuestionsRawValue = newValue.joined(separator: "\n")
        }
    }
}
