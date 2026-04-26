import AVFoundation
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(Theme.self) private var theme
    @Environment(ProfileManager.self) private var profileManager
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \LocalUserProfile.createdAt) private var profiles: [LocalUserProfile]
    @Query(sort: \TrainingVideoPost.uploadedAt, order: .reverse) private var posts: [TrainingVideoPost]
    @Query(sort: \UploadedTrainingVideoRecord.uploadedAt, order: .reverse)
    private var legacyRecords: [UploadedTrainingVideoRecord]

    @State private var uploadViewModel = TrainingUploadViewModel()
    @State private var homeViewModel = HomeViewModel()
    @State private var selectedPlayerFilterID = MemberFilterChips.allMembersID
    @State private var isPresentingUserManagement = false
    @State private var isPresentingSourceSheet = false
    @State private var activePickerAction: VideoSourceAction?
    @State private var pendingVideoDraft: PendingVideoDraft?
    @State private var queuedVideoDraft: PendingVideoDraft?
    @State private var shouldDiscardPendingDraftOnDismiss = true
    @State private var mediaFlowAlert: MediaFlowAlert?
    @State private var lastPresentedDraft: PendingVideoDraft?
    @State private var selectedDetailPost: TrainingVideoPost?
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                    if isParentView, !playerProfiles.isEmpty {
                        MemberFilterChips(
                            profiles: playerProfiles,
                            selectedID: $selectedPlayerFilterID
                        )
                        .padding(.bottom, theme.spacing.medium)
                    }

                    if uploadViewModel.isUploading || uploadViewModel.statusMessage != nil {
                        uploadProgressRow
                            .padding(.horizontal, theme.spacing.pageMargin)
                            .padding(.bottom, theme.spacing.medium)
                    }

                    if feedSections.isEmpty {
                        emptyState
                            .padding(.horizontal, theme.spacing.pageMargin)
                            .padding(.top, theme.spacing.xLarge)
                    } else {
                        ForEach(feedSections) { section in
                            VStack(alignment: .leading, spacing: theme.spacing.small) {
                                Text(section.title)
                                    .font(theme.typography.captionEmphasis)
                                    .foregroundStyle(theme.colors.textSecondary)
                                    .padding(.horizontal, theme.spacing.pageMargin)

                                ForEach(section.posts, id: \.id) { post in
                                    TrainingVideoPostCard(
                                        post: post,
                                        memberProfile: profileByID[post.playerID],
                                        showsMember: isParentView,
                                        onOpenDetail: { selectedDetailPost = $0 },
                                        onDelete: canDelete(post: post)
                                            ? { homeViewModel.deletePost($0, context: modelContext) }
                                            : nil
                                    )
                                    .padding(.horizontal, theme.spacing.pageMargin)
                                }
                            }
                            .padding(.bottom, theme.spacing.sectionGap)
                        }
                    }
                }
                .padding(.top, theme.spacing.medium)
                .padding(.bottom, theme.spacing.large)
            }

            if isPresentingSourceSheet {
                sourceSheetOverlay
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(navigationTitle)
                    .font(theme.typography.bodyEmphasis)
                    .foregroundStyle(theme.colors.textPrimary)
            }

            if isParentView {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingUserManagement = true
                    } label: {
                        Image(systemName: "person.2.fill")
                    }
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingSourceSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(uploadViewModel.isUploading)
                }
            }
        }
        .hoopScreenBackground(theme)
        .sheet(isPresented: $isPresentingUserManagement) {
            UserManagementView()
        }
        .navigationDestination(isPresented: selectedDetailBinding) {
            if let selectedDetailPost {
                TrainingVideoPostDetailView(
                    post: selectedDetailPost,
                    memberProfile: profileByID[selectedDetailPost.playerID],
                    onRunAnalysis: { _ in },
                    onDelete: canDelete(post: selectedDetailPost)
                        ? { homeViewModel.deletePost($0, context: modelContext) }
                        : nil
                )
            }
        }
        .sheet(item: $activePickerAction, onDismiss: presentQueuedComposerIfNeeded) { source in
            SystemVideoPickerView(
                source: source,
                onPick: { url in
                    queueDraft(from: url, source: source)
                },
                onCancel: {
                    activePickerAction = nil
                }
            )
        }
        .fullScreenCover(item: $pendingVideoDraft, onDismiss: handleComposerDismissed) { draft in
            VideoComposerView(videoURL: draft.fileURL, source: draft.source) { contentType, drillName in
                publishPendingVideo(draft, contentType: contentType, drillName: drillName)
            }
        }
        .alert("上传失败", isPresented: Binding(
            get: { uploadViewModel.alertMessage != nil },
            set: { if !$0 { uploadViewModel.clearAlert() } }
        )) {
            Button("知道了", role: .cancel) { uploadViewModel.clearAlert() }
        } message: {
            Text(uploadViewModel.alertMessage ?? "请稍后重试。")
        }
        .alert(
            mediaFlowAlert?.title ?? "",
            isPresented: Binding(
                get: { mediaFlowAlert != nil },
                set: { if !$0 { mediaFlowAlert = nil } }
            )
        ) {
            if mediaFlowAlert?.showsSettingsAction == true {
                Button("去设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                    mediaFlowAlert = nil
                }
            }
            Button("知道了", role: .cancel) {
                mediaFlowAlert = nil
            }
        } message: {
            Text(mediaFlowAlert?.message ?? "")
        }
        .task(id: migrationSignature) {
            homeViewModel.migrateLegacyRecordsIfNeeded(
                legacyRecords: legacyRecords,
                posts: posts,
                context: modelContext
            )
        }
        .animation(.easeInOut(duration: 0.22), value: isPresentingSourceSheet)
    }

    // MARK: - Upload progress

    private var uploadProgressRow: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xxxSmall) {
            HStack {
                if let statusMessage = uploadViewModel.statusMessage {
                    Text(statusMessage)
                        .font(theme.typography.callout)
                        .foregroundStyle(theme.colors.textSecondary)
                }
                Spacer()
                if !uploadViewModel.isUploading {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.colors.success)
                        .font(theme.typography.callout)
                }
            }

            if uploadViewModel.isUploading {
                ProgressView(value: uploadViewModel.progress)
                    .tint(theme.colors.brand)
            }
        }
        .padding(theme.spacing.small)
        .background(theme.colors.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous)
                .stroke(theme.colors.border, lineWidth: theme.stroke.thin)
        }
    }

    private var sourceSheetOverlay: some View {
        ZStack(alignment: .bottom) {
            Button {
                isPresentingSourceSheet = false
            } label: {
                Color.black.opacity(0.22)
                    .ignoresSafeArea()
            }
            .buttonStyle(.plain)

            VStack(spacing: theme.spacing.xSmall) {
                VStack(spacing: 0) {
                    sourceSheetButton(
                        title: "拍摄视频",
                        systemImage: "video.fill"
                    ) {
                        handleSourceSelection(.camera)
                    }

                    Divider()
                        .padding(.leading, 52)

                    sourceSheetButton(
                        title: "从相册选择",
                        systemImage: "photo.on.rectangle.angled"
                    ) {
                        handleSourceSelection(.library)
                    }
                }
                .background(theme.colors.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous))

                Button("取消", role: .cancel) {
                    isPresentingSourceSheet = false
                }
                .font(theme.typography.bodyEmphasis)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacing.small)
                .background(theme.colors.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous))
            }
            .padding(.horizontal, theme.spacing.pageMargin)
            .padding(.bottom, theme.spacing.large)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func sourceSheetButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.small) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.colors.brand)
                    .frame(width: 28)

                Text(title)
                    .font(theme.typography.bodyEmphasis)
                    .foregroundStyle(theme.colors.textPrimary)

                Spacer()
            }
            .padding(.horizontal, theme.spacing.medium)
            .padding(.vertical, theme.spacing.medium)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        Group {
            if isParentView && playerProfiles.isEmpty {
                parentNoMembersEmptyState
            } else if isParentView && filteredPosts.isEmpty {
                filteredEmptyState
            } else {
                playerEmptyState
            }
        }
    }

    private var playerEmptyState: some View {
        VStack(spacing: theme.spacing.medium) {
            Text("🏀")
                .font(.system(size: 48))

            VStack(spacing: theme.spacing.xSmall) {
                Text("还没有视频")
                    .font(theme.typography.title3)
                    .foregroundStyle(theme.colors.textPrimary)

                Text("上传第一条训练或比赛视频，\n开始积累成长记录。")
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var parentNoMembersEmptyState: some View {
        VStack(spacing: theme.spacing.xSmall) {
            Text("去「我的」添加球员成员后，")
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textSecondary)
            Text("这里会显示家庭视频动态。")
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var filteredEmptyState: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xSmall) {
            Text("该成员还没有视频")
                .font(theme.typography.bodyEmphasis)
                .foregroundStyle(theme.colors.textPrimary)

            Text("切回全部成员，或者等待这位成员上传第一条视频。")
                .font(theme.typography.callout)
                .foregroundStyle(theme.colors.textSecondary)
        }
        .padding(theme.spacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous))
    }

    // MARK: - Computed properties

    private var navigationTitle: String {
        if isParentView {
            return "家庭视频"
        }

        if let name = currentProfile?.displayName {
            return "\(currentProfile?.avatarEmoji ?? "⛹️") \(name)的视频"
        }

        return "我的视频"
    }

    private var currentProfile: LocalUserProfile? {
        profileManager.currentProfile
    }

    private var isParentView: Bool {
        currentProfile?.role == .parent
    }

    private var playerProfiles: [LocalUserProfile] {
        profiles.filter { $0.role == .player }
    }

    private var profileByID: [String: LocalUserProfile] {
        Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
    }

    private var allVisiblePosts: [TrainingVideoPost] {
        if isParentView {
            return posts.filter { profileByID[$0.playerID]?.role == .player }
        }

        guard let currentProfile else { return [] }
        return posts.filter { $0.playerID == currentProfile.id }
    }

    private var filteredPosts: [TrainingVideoPost] {
        if isParentView, selectedPlayerFilterID != MemberFilterChips.allMembersID {
            return allVisiblePosts.filter { $0.playerID == selectedPlayerFilterID }
        }

        return allVisiblePosts
    }

    private var feedSections: [HomeFeedSection] {
        guard !filteredPosts.isEmpty else { return [] }

        let groupedPosts = Dictionary(grouping: filteredPosts, by: \.createdDay)

        return groupedPosts.keys
            .sorted(by: >)
            .map { day in
                HomeFeedSection(
                    day: day,
                    posts: groupedPosts[day, default: []].sorted { $0.uploadedAt > $1.uploadedAt }
                )
            }
    }

    private var migrationSignature: String {
        "\(legacyRecords.count)-\(posts.count)"
    }

    private var selectedDetailBinding: Binding<Bool> {
        Binding(
            get: { selectedDetailPost != nil },
            set: {
                if !$0 {
                    selectedDetailPost = nil
                }
            }
        )
    }

    private func canDelete(post: TrainingVideoPost) -> Bool {
        guard let currentProfile else { return false }
        return currentProfile.role.canDeleteVideo(postPlayerID: post.playerID, currentProfileID: currentProfile.id)
    }

    private func handleSourceSelection(_ source: VideoSourceAction) {
        isPresentingSourceSheet = false

        switch source {
        case .library:
            activePickerAction = .library
        case .camera:
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                mediaFlowAlert = .cameraUnavailable
                return
            }

            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                activePickerAction = .camera
            case .notDetermined:
                Task {
                    let granted = await AVCaptureDevice.requestAccess(for: .video)
                    await MainActor.run {
                        if granted {
                            activePickerAction = .camera
                        } else {
                            mediaFlowAlert = .cameraPermissionDenied
                        }
                    }
                }
            case .denied, .restricted:
                mediaFlowAlert = .cameraPermissionDenied
            @unknown default:
                mediaFlowAlert = .cameraPermissionDenied
            }
        }
    }

    private func queueDraft(from fileURL: URL, source: VideoSourceAction) {
        queuedVideoDraft = PendingVideoDraft(fileURL: fileURL, source: source)
        activePickerAction = nil
    }

    private func presentQueuedComposerIfNeeded() {
        guard let draft = queuedVideoDraft else { return }
        queuedVideoDraft = nil

        Task { @MainActor in
            // Let the system picker finish dismissing before presenting the next full-screen layer.
            try? await Task.sleep(for: .milliseconds(180))
            lastPresentedDraft = draft
            pendingVideoDraft = draft
            shouldDiscardPendingDraftOnDismiss = true
        }
    }

    private func publishPendingVideo(
        _ draft: PendingVideoDraft,
        contentType: TrainingVideoContentType,
        drillName: String?
    ) {
        shouldDiscardPendingDraftOnDismiss = false
        pendingVideoDraft = nil

        Task {
            guard let currentProfile else {
                uploadViewModel.handleSelectionFailure(ProfileSelectionError.noActiveProfile)
                try? FileManager.default.removeItem(at: draft.fileURL)
                return
            }

            await uploadViewModel.uploadVideo(
                from: draft.fileURL,
                userID: currentProfile.id,
                contentType: contentType,
                context: modelContext
            )
        }
    }

    private func handleComposerDismissed() {
        defer {
            shouldDiscardPendingDraftOnDismiss = true
            lastPresentedDraft = nil
        }

        guard shouldDiscardPendingDraftOnDismiss,
              let draft = lastPresentedDraft else { return }

        try? FileManager.default.removeItem(at: draft.fileURL)
    }
}

// MARK: - Feed Section

private struct HomeFeedSection: Identifiable {
    let day: Date
    let posts: [TrainingVideoPost]

    var id: Date { day }

    var title: String {
        let calendar = Calendar.autoupdatingCurrent
        if calendar.isDateInToday(day) { return "今天" }
        if calendar.isDateInYesterday(day) { return "昨天" }
        return Self.dateFormatter.string(from: day)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}

// MARK: - Errors

private enum ProfileSelectionError: LocalizedError {
    case noActiveProfile

    var errorDescription: String? {
        switch self {
        case .noActiveProfile:
            "当前没有选中成员，请先返回身份选择页。"
        }
    }
}

private struct MediaFlowAlert {
    let title: String
    let message: String
    let showsSettingsAction: Bool

    static let cameraUnavailable = MediaFlowAlert(
        title: "无法拍摄视频",
        message: "当前设备不支持拍摄视频，请改用“从相册选择”继续发布。",
        showsSettingsAction: false
    )

    static let cameraPermissionDenied = MediaFlowAlert(
        title: "需要相机权限",
        message: "请在系统设置中允许 Hoop 使用相机后，再拍摄视频发布动态。",
        showsSettingsAction: true
    )
}

#Preview {
    NavigationStack {
        HomeView()
            .environment(Theme())
            .environment(ProfileManager())
    }
}
