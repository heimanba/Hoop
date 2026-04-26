import Foundation
import SwiftData

enum VideoAnalysisMessageSender: String, Codable {
    case user
    case assistant
    case system
}

enum VideoAnalysisMessageType: String, Codable {
    case initialAnalysis
    case followUpQuestion
    case followUpAnswer
    case system
}

enum VideoAnalysisGenerationStatus: String, Codable {
    case pending
    case streaming
    case completed
    case failed
}

@Model
final class VideoAnalysisMessage {
    @Attribute(.unique) var id: String
    var sessionID: String
    var videoID: String
    var senderRawValue: String
    var messageTypeRawValue: String
    var text: String
    var createdAt: Date
    var generationStatusRawValue: String

    init(
        id: String = UUID().uuidString,
        sessionID: String,
        videoID: String,
        sender: VideoAnalysisMessageSender,
        messageType: VideoAnalysisMessageType,
        text: String,
        createdAt: Date = Date(),
        generationStatus: VideoAnalysisGenerationStatus = .completed
    ) {
        self.id = id
        self.sessionID = sessionID
        self.videoID = videoID
        self.senderRawValue = sender.rawValue
        self.messageTypeRawValue = messageType.rawValue
        self.text = text
        self.createdAt = createdAt
        self.generationStatusRawValue = generationStatus.rawValue
    }

    var sender: VideoAnalysisMessageSender {
        get { VideoAnalysisMessageSender(rawValue: senderRawValue) ?? .assistant }
        set { senderRawValue = newValue.rawValue }
    }

    var messageType: VideoAnalysisMessageType {
        get { VideoAnalysisMessageType(rawValue: messageTypeRawValue) ?? .system }
        set { messageTypeRawValue = newValue.rawValue }
    }

    var generationStatus: VideoAnalysisGenerationStatus {
        get { VideoAnalysisGenerationStatus(rawValue: generationStatusRawValue) ?? .completed }
        set { generationStatusRawValue = newValue.rawValue }
    }
}
