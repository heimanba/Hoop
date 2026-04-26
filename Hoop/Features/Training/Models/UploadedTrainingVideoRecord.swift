import Foundation
import SwiftData

@Model
final class UploadedTrainingVideoRecord {
    @Attribute(.unique) var id: String
    var playerID: String
    var objectKey: String
    var fileName: String
    var trainingDate: Date
    var uploadedAt: Date
    var fileSize: Int64

    init(
        id: String = UUID().uuidString,
        playerID: String,
        objectKey: String,
        fileName: String,
        trainingDate: Date,
        uploadedAt: Date,
        fileSize: Int64
    ) {
        self.id = id
        self.playerID = playerID
        self.objectKey = objectKey
        self.fileName = fileName
        self.trainingDate = Self.normalizedDay(for: trainingDate)
        self.uploadedAt = uploadedAt
        self.fileSize = fileSize
    }

    static func normalizedDay(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> Date {
        calendar.startOfDay(for: date)
    }
}
