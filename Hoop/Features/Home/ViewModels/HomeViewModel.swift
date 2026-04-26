import Foundation
import SwiftData

@MainActor
@Observable
final class HomeViewModel {

    // MARK: - Delete

    func deletePost(_ post: TrainingVideoPost, context: ModelContext) {
        deleteAnalysisArtifacts(for: post, context: context)
        post.deleteLocalFiles()
        context.delete(post)
        try? context.save()
    }

    private func deleteAnalysisArtifacts(for post: TrainingVideoPost, context: ModelContext) {
        let videoID = post.id
        let sessions = (try? context.fetch(FetchDescriptor<VideoAnalysisSession>(
            predicate: #Predicate { $0.videoID == videoID }
        ))) ?? []
        let messages = (try? context.fetch(FetchDescriptor<VideoAnalysisMessage>(
            predicate: #Predicate { $0.videoID == videoID }
        ))) ?? []

        for message in messages { context.delete(message) }
        for session in sessions { context.delete(session) }
    }

    // MARK: - Migration

    func migrateLegacyRecordsIfNeeded(
        legacyRecords: [UploadedTrainingVideoRecord],
        posts: [TrainingVideoPost],
        context: ModelContext
    ) {
        let existingObjectKeys = Set(posts.map(\.objectKey))
        let recordsToMigrate = legacyRecords.filter { !existingObjectKeys.contains($0.objectKey) }
        guard !recordsToMigrate.isEmpty else { return }

        for record in recordsToMigrate {
            context.insert(TrainingVideoPost.fromLegacyRecord(record))
        }
        try? context.save()
    }
}
