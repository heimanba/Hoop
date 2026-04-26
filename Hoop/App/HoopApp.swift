import SwiftData
import SwiftUI

@main
struct HoopApp: App {
    @State private var theme = Theme()
    @State private var profileManager = ProfileManager()
    private let modelContainer: ModelContainer = Self.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(theme)
                .environment(profileManager)
                .modelContainer(modelContainer)
        }
    }
}

private extension HoopApp {
    static func makeModelContainer() -> ModelContainer {
        do {
            return try freshModelContainer()
        } catch {
            clearLocalModelStore()

            do {
                return try freshModelContainer()
            } catch {
                fatalError("Failed to create model container: \(error)")
            }
        }
    }

    static func freshModelContainer() throws -> ModelContainer {
        try ModelContainer(
            for: AuthSessionRecord.self,
            LocalUserProfile.self,
            UploadedTrainingVideoRecord.self,
            TrainingVideoPost.self,
            VideoAnalysisSession.self,
            VideoAnalysisMessage.self
        )
    }

    static func clearLocalModelStore() {
        let fileManager = FileManager.default
        let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let storeBaseURL = applicationSupportDirectory.appendingPathComponent("default.store")
        let candidateURLs = [
            storeBaseURL,
            storeBaseURL.appendingPathExtension("shm"),
            storeBaseURL.appendingPathExtension("wal")
        ]

        for url in candidateURLs where fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }
}
