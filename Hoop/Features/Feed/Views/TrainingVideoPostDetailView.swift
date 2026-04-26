import AVKit
import SwiftData
import SwiftUI

struct TrainingVideoPostDetailView: View {
    @Environment(Theme.self) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let post: TrainingVideoPost
    let memberProfile: LocalUserProfile?
    let onRunAnalysis: (TrainingVideoPost) -> Void
    let onDelete: ((TrainingVideoPost) -> Void)?

    @State private var playbackController: VideoPlaybackController?
    @State private var followUpDraft = ""
    @State private var isPresentingDeleteConfirmation = false
    @State private var activeSession: VideoAnalysisSession?
    @State private var sessionMessages: [VideoAnalysisMessage] = []
    @State private var selectedTag: VideoAnalysisTag
    @State private var isStartingAnalysis = false
    @State private var isReplying = false

    @State private var isShowingActionMenu = false
    @State private var completionHapticTrigger = 0
    @State private var errorHapticTrigger = 0
    @State private var menuToggleHapticTrigger = 0
    @State private var activeGenerationTask: Task<Void, Never>?

    init(
        post: TrainingVideoPost,
        memberProfile: LocalUserProfile?,
        onRunAnalysis: @escaping (TrainingVideoPost) -> Void,
        onDelete: ((TrainingVideoPost) -> Void)?
    ) {
        self.post = post
        self.memberProfile = memberProfile
        self.onRunAnalysis = onRunAnalysis
        self.onDelete = onDelete
        _selectedTag = State(initialValue: VideoAnalysisTag.defaultTag(for: post.contentType))
    }

    var body: some View {
        chatContentArea
        .safeAreaInset(edge: .bottom) {
            composerBarContainer
        }
        .navigationTitle("AI 教练")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .hoopScreenBackground(theme)
        .toolbar {
            if onDelete != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("删除", role: .destructive) {
                        isPresentingDeleteConfirmation = true
                    }
                }
            }
            if let activeSession {
                ToolbarItem(placement: .topBarLeading) {
                    StatusBadge(
                        title: activeSession.sessionStatus.title,
                        tone: sessionTone(for: activeSession)
                    )
                }
            }
        }
        .confirmationDialog(
            "确定要删除这条视频动态吗？",
            isPresented: $isPresentingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除视频动态", role: .destructive) {
                onDelete?(post)
                dismiss()
            }
        } message: {
            Text("本地记录和缓存将被移除，已上传的视频文件不会被删除。")
        }
        .fullScreenCover(isPresented: fullScreenBinding) {
            if let player = playbackController?.player {
                TrainingVideoPlayerScreen(player: player)
            }
        }
        .task(id: post.id) {
            let controller = VideoPlaybackController(
                objectKey: post.objectKey,
                remoteVideoURL: post.remoteVideoURL
            )
            playbackController = controller
            await loadAnalysisState()
            await controller.preloadIfNeeded()
        }
        .onDisappear {
            playbackController?.tearDown(
                keepPlayerForFullScreen: playbackController?.isPresentingFullScreenPlayer ?? false
            )
        }
        .sensoryFeedback(.success, trigger: completionHapticTrigger)
        .sensoryFeedback(.error, trigger: errorHapticTrigger)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: menuToggleHapticTrigger)
    }

    // MARK: - Full Screen Binding

    private var fullScreenBinding: Binding<Bool> {
        Binding(
            get: { playbackController?.isPresentingFullScreenPlayer ?? false },
            set: { playbackController?.isPresentingFullScreenPlayer = $0 }
        )
    }

    // MARK: - Chat Content Area

    private var chatContentArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.small) {
                    if let playbackController {
                        VideoContextCard(
                            post: post,
                            memberProfile: memberProfile,
                            playbackController: playbackController
                        )
                        .padding(.top, theme.spacing.small)
                    }

                    if sessionMessages.isEmpty {
                        tagStarterView
                            .padding(.top, theme.spacing.xSmall)
                    } else {
                        ForEach(sessionMessages, id: \.id) { message in
                            conversationBubble(for: message)
                                .id(message.id)
                        }
                        if let lastMsg = sessionMessages.last,
                           lastMsg.sender == .assistant,
                           lastMsg.generationStatus == .completed,
                           !recommendedQuestions.isEmpty,
                           !isBusy {
                            suggestedQuestionsInlineChips
                        }
                    }
                }
                .padding(.horizontal, theme.spacing.pageMargin)
                .padding(.vertical, theme.spacing.small)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: sessionMessages.count, initial: true) {
                guard let lastMessageID = sessionMessages.last?.id else { return }
                withAnimation(.easeOut(duration: 0.22)) {
                    proxy.scrollTo(lastMessageID, anchor: .bottom)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onTapGesture {
            if isShowingActionMenu {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isShowingActionMenu = false
                }
                menuToggleHapticTrigger += 1
            }
        }
    }

    // MARK: - Composer Bar Container

    private var composerBarContainer: some View {
        VStack(spacing: 0) {
            if isShowingActionMenu {
                actionMenuPanel
                    .background(theme.colors.surfaceRaised)
                    .clipShape(
                        .rect(
                            topLeadingRadius: theme.radius.large,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: theme.radius.large
                        )
                    )
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: theme.stroke.thin / 2)
                            .fill(theme.colors.border)
                            .frame(height: theme.stroke.thin)
                    }
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        )
                    )
            }
            Divider()
            composerBar
                .padding(.horizontal, theme.spacing.pageMargin)
                .padding(.vertical, theme.spacing.small)
        }
        .background(theme.colors.surfaceRaised)
    }

    // MARK: - Action Menu Panel

    private var actionMenuPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(theme.colors.borderStrong)
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, theme.spacing.small)
                .padding(.bottom, theme.spacing.xSmall)

            Text("分析角度")
                .font(theme.typography.captionEmphasis)
                .foregroundStyle(theme.colors.textSecondary)
                .padding(.horizontal, theme.spacing.pageMargin)
                .padding(.bottom, theme.spacing.xSmall)

            ForEach(availableTags, id: \.self) { tag in
                let isCurrent = tag == (activeSession?.selectedTag ?? selectedTag)
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isShowingActionMenu = false
                    }
                    menuToggleHapticTrigger += 1
                    guard !isCurrent else { return }
                    selectedTag = tag
                    followUpDraft = suggestedPrompt(for: tag)
                } label: {
                    HStack(spacing: theme.spacing.small) {
                        Image(systemName: tagSystemImage(for: tag))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(isCurrent ? theme.colors.ai : theme.colors.textSecondary)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tag.title)
                                .font(theme.typography.bodyEmphasis)
                                .foregroundStyle(isCurrent ? theme.colors.ai : theme.colors.textPrimary)
                            Text(tag.promptHint(for: post.contentType))
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        if isCurrent {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(theme.colors.ai)
                        }
                    }
                    .padding(.horizontal, theme.spacing.pageMargin)
                    .padding(.vertical, theme.spacing.xSmall)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
            }

            if activeSession != nil, !sessionMessages.isEmpty {
                Divider()
                    .padding(.horizontal, theme.spacing.pageMargin)
                    .padding(.top, theme.spacing.xSmall)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isShowingActionMenu = false
                    }
                    menuToggleHapticTrigger += 1
                    followUpDraft = suggestedPrompt(for: selectedTag)
                } label: {
                    HStack(spacing: theme.spacing.small) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(theme.colors.textSecondary)
                            .frame(width: 22)
                        Text("重新分析")
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colors.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, theme.spacing.pageMargin)
                    .padding(.vertical, theme.spacing.xSmall)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
            }

            Spacer().frame(height: theme.spacing.xSmall)
        }
    }

    private func suggestedPrompt(for tag: VideoAnalysisTag) -> String {
        let action = sessionMessages.isEmpty ? "分析" : "重新分析"
        return "请以「\(post.contentType.title) / \(tag.title)」的角度\(action)：\(tag.promptHint(for: post.contentType))"
    }

    private func tagSystemImage(for tag: VideoAnalysisTag) -> String {
        switch tag {
        case .trainingForm: "figure.stand"
        case .trainingRhythm: "waveform"
        case .trainingForceBalance: "scalemass"
        case .trainingStability: "scope"
        case .trainingPriorityFix: "exclamationmark.circle"
        case .matchDecision: "brain.head.profile"
        case .matchTiming: "timer"
        case .matchSpacing: "arrow.up.left.and.arrow.down.right"
        case .matchShotSelection: "hand.point.up"
        case .matchDefensiveRead: "eye"
        }
    }

    // MARK: - Tag Starter (empty state)

    private var tagStarterView: some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            HStack(alignment: .top, spacing: theme.spacing.small) {
                avatar(title: "AI", tint: theme.colors.ai, background: theme.colors.ai.opacity(0.14))
                VStack(alignment: .leading, spacing: theme.spacing.xxxSmall) {
                    Text("AI 教练")
                        .font(theme.typography.captionEmphasis)
                        .foregroundStyle(theme.colors.ai)
                    Text("你好！选择一个分析角度，我会立刻围绕这条视频展开分析。")
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textPrimary)
                }
                .padding(theme.spacing.small)
                .background(theme.colors.surfaceRaised)
                .overlay {
                    RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous)
                        .stroke(theme.colors.border, lineWidth: theme.stroke.thin)
                }
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous))
                Spacer(minLength: theme.spacing.xLarge)
            }
        }
    }

    // MARK: - Inline Suggested Questions

    private var suggestedQuestionsInlineChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacing.xSmall) {
                ForEach(recommendedQuestions, id: \.self) { question in
                    Button(question) {
                        sendFollowUp(question)
                    }
                    .buttonStyle(.plain)
                    .font(theme.typography.callout)
                    .foregroundStyle(theme.colors.textPrimary)
                    .padding(.horizontal, theme.spacing.small)
                    .padding(.vertical, theme.spacing.xSmall)
                    .background(theme.colors.surfaceRaised)
                    .overlay {
                        RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous)
                            .stroke(theme.colors.borderStrong, lineWidth: theme.stroke.thin)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous))
                    .opacity(isBusy ? 0.45 : 1)
                    .disabled(isBusy)
                }
            }
            .padding(.leading, 38)
        }
    }

    // MARK: - Composer Bar

    private var composerBar: some View {
        HStack(alignment: .bottom, spacing: theme.spacing.xSmall) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    isShowingActionMenu.toggle()
                }
                menuToggleHapticTrigger += 1
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.colors.textPrimary)
                    .rotationEffect(.degrees(isShowingActionMenu ? 45 : 0))
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isShowingActionMenu)
                    .frame(width: theme.spacing.controlHeight, height: theme.spacing.controlHeight)
                    .background(theme.colors.fillStrong)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            composerInputField
        }
    }

    private var composerInputField: some View {
        ZStack(alignment: .bottomTrailing) {
            TextField(activeSession != nil ? "继续追问…" : "选择分析角度或直接输入…", text: $followUpDraft, axis: .vertical)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(1 ... 5)
                .textInputAutocapitalization(.sentences)
                .padding(.leading, theme.spacing.small)
                .padding(.trailing, theme.spacing.controlHeight + theme.spacing.small)
                .padding(.vertical, theme.spacing.small)
                .disabled(isBusy)

            if isBusy {
                Button("停止", systemImage: "stop.fill") {
                    cancelGeneration()
                }
                .labelStyle(.iconOnly)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(theme.colors.textPrimary)
                .frame(width: theme.spacing.controlHeight - 4, height: theme.spacing.controlHeight - 4)
                .background(theme.colors.fillStrong)
                .clipShape(Circle())
                .buttonStyle(.plain)
                .padding(.trailing, 6)
                .padding(.bottom, 6)
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            } else {
                Button("发送", systemImage: "arrow.up") {
                    sendComposerDraft()
                }
                .labelStyle(.iconOnly)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(theme.colors.textOnBrand)
                .frame(width: theme.spacing.controlHeight - 4, height: theme.spacing.controlHeight - 4)
                .background(isSendDisabled ? theme.colors.disabled : theme.colors.brand)
                .clipShape(Circle())
                .buttonStyle(.plain)
                .disabled(isSendDisabled)
                .padding(.trailing, 6)
                .padding(.bottom, 6)
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isBusy)
        .background(theme.colors.fill)
        .overlay {
            RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous)
                .stroke(theme.colors.border, lineWidth: theme.stroke.thin)
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous))
    }

    private var availableTags: [VideoAnalysisTag] {
        VideoAnalysisTag.tags(for: post.contentType)
    }

    private var recommendedQuestions: [String] {
        if let activeSession, !activeSession.recommendedQuestions.isEmpty {
            return activeSession.recommendedQuestions
        }

        return fallbackQuestions
    }

    private var fallbackQuestions: [String] {
        switch post.contentType {
        case .training:
            [
                "如果只改一个点，你建议我先改哪个？",
                "你说的问题主要出现在什么动作段？",
                "下次补拍什么角度会更方便你判断？"
            ]
        case .match:
            [
                "如果先调一个判断点，你建议我先调哪个？",
                "这个问题更像出现在回合的哪个节点？",
                "下次补什么片段会更方便你继续分析？"
            ]
        case .duel:
            [
                "如果先调一个对抗点，你建议我先调哪个？",
                "这个问题更像出现在进攻还是防守环节？",
                "下次补什么片段会更方便你继续分析？"
            ]
        }
    }

    private var isBusy: Bool {
        isStartingAnalysis || isReplying
    }

    private var isSendDisabled: Bool {
        followUpDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBusy
    }

    @MainActor
    private func loadAnalysisState() async {
        let videoID = post.id
        let sessions = (try? modelContext.fetch(FetchDescriptor<VideoAnalysisSession>(
            predicate: #Predicate { $0.videoID == videoID },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        ))) ?? []

        if let currentSession = sessions.first(where: { $0.sessionStatus != .archived }) ?? sessions.first {
            let sessionID = currentSession.id
            activeSession = currentSession
            selectedTag = currentSession.selectedTag
            sessionMessages = (try? modelContext.fetch(FetchDescriptor<VideoAnalysisMessage>(
                predicate: #Predicate { $0.sessionID == sessionID },
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            ))) ?? []
            syncPostStatus(with: currentSession)
        } else {
            activeSession = nil
            sessionMessages = []
            selectedTag = VideoAnalysisTag.defaultTag(for: post.contentType)
        }
    }

    private func startAnalysisFromSelectedTag() {
        guard !isBusy else { return }

        activeGenerationTask = Task {
            await beginAnalysisSession(initialPrompt: nil)
        }
    }

    private func sendComposerDraft() {
        let trimmedDraft = followUpDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDraft.isEmpty else { return }

        if activeSession == nil {
            guard !isBusy else { return }
            activeGenerationTask = Task {
                await beginAnalysisSession(initialPrompt: trimmedDraft)
            }
        } else {
            sendFollowUp(trimmedDraft)
        }
    }

    @MainActor
    private func beginAnalysisSession(initialPrompt: String?) async {
        isStartingAnalysis = true
        defer { isStartingAnalysis = false }

        let trimmedPrompt = initialPrompt?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let activeSession {
            activeSession.sessionStatus = .archived
        }

        let newSession = VideoAnalysisSession(
            videoID: post.id,
            selectedTag: selectedTag,
            sessionStatus: .generatingInitialMessage,
            lastMessageAt: Date()
        )
        let now = Date()
        let userMessage = trimmedPrompt.map {
            VideoAnalysisMessage(
                sessionID: newSession.id,
                videoID: post.id,
                sender: .user,
                messageType: .followUpQuestion,
                text: $0,
                createdAt: now
            )
        }
        let pendingMessage = VideoAnalysisMessage(
            sessionID: newSession.id,
            videoID: post.id,
            sender: .assistant,
            messageType: .initialAnalysis,
            text: "正在围绕“\(selectedTag.title)”生成首条分析消息…",
            createdAt: now.addingTimeInterval(0.001),
            generationStatus: .pending
        )

        newSession.initialAnalysisMessageID = pendingMessage.id
        modelContext.insert(newSession)
        if let userMessage {
            modelContext.insert(userMessage)
        }
        modelContext.insert(pendingMessage)

        activeSession = newSession
        sessionMessages = [userMessage, pendingMessage].compactMap { $0 }
        followUpDraft = ""
        post.analysisStatus = .processing
        post.latestAnalysisErrorMessage = nil

        try? modelContext.save()

        do {
            let service = try AIAnalysisService()
            let result = try await service.generateInitialConversation(
                for: post,
                selectedTag: selectedTag,
                initialPrompt: trimmedPrompt
            )

            pendingMessage.text = Self.messageText(from: result)
            pendingMessage.generationStatus = .completed
            newSession.sessionStatus = .ready
            newSession.completedAt = result.generatedAt
            newSession.failedAt = nil
            newSession.lastMessageAt = result.generatedAt
            newSession.lastErrorMessage = nil
            newSession.modelName = result.modelName
            newSession.recommendedQuestions = result.recommendedQuestions.isEmpty ? fallbackQuestions : result.recommendedQuestions

            cacheLegacyAnalysisSummary(using: result, selectedTag: selectedTag)
            try modelContext.save()
            completionHapticTrigger += 1
            await loadAnalysisState()
        } catch is CancellationError {
            if let userMessage {
                modelContext.delete(userMessage)
            }
            modelContext.delete(pendingMessage)
            modelContext.delete(newSession)
            activeSession = nil
            sessionMessages = []
            post.analysisStatus = .idle
            post.latestAnalysisErrorMessage = nil
            try? modelContext.save()
            await loadAnalysisState()
        } catch {
            pendingMessage.text = "这次首轮分析没有成功生成。\n\n\(error.localizedDescription)"
            pendingMessage.generationStatus = .failed
            newSession.sessionStatus = .failed
            newSession.failedAt = Date()
            newSession.lastErrorMessage = error.localizedDescription
            post.analysisStatus = .failed
            post.latestAnalysisErrorMessage = error.localizedDescription
            post.analysisUpdatedAt = Date()
            try? modelContext.save()
            errorHapticTrigger += 1
            await loadAnalysisState()
        }
    }

    private func sendFollowUp(_ question: String) {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty, !isBusy else { return }

        activeGenerationTask = Task {
            await continueConversation(with: trimmedQuestion)
        }
    }

    private func cancelGeneration() {
        activeGenerationTask?.cancel()
        activeGenerationTask = nil
    }

    @MainActor
    private func continueConversation(with question: String) async {
        guard let activeSession, activeSession.sessionStatus != .archived else { return }

        isReplying = true
        defer { isReplying = false }

        let now = Date()
        let userMessage = VideoAnalysisMessage(
            sessionID: activeSession.id,
            videoID: post.id,
            sender: .user,
            messageType: .followUpQuestion,
            text: question,
            createdAt: now
        )
        let pendingReply = VideoAnalysisMessage(
            sessionID: activeSession.id,
            videoID: post.id,
            sender: .assistant,
            messageType: .followUpAnswer,
            text: "正在整理回复…",
            createdAt: now.addingTimeInterval(0.001),
            generationStatus: .pending
        )

        modelContext.insert(userMessage)
        modelContext.insert(pendingReply)
        followUpDraft = ""
        activeSession.sessionStatus = .replying
        activeSession.lastMessageAt = Date()
        post.analysisStatus = .processing
        try? modelContext.save()
        await loadAnalysisState()

        do {
            let service = try AIAnalysisService()
            let history = sessionMessages.filter { $0.id != pendingReply.id }
            let result = try await service.replyInConversation(
                for: post,
                selectedTag: activeSession.selectedTag,
                history: history,
                question: question
            )

            pendingReply.text = Self.messageText(from: result)
            pendingReply.generationStatus = .completed
            activeSession.sessionStatus = .ready
            activeSession.completedAt = result.generatedAt
            activeSession.failedAt = nil
            activeSession.lastMessageAt = result.generatedAt
            activeSession.lastErrorMessage = nil
            activeSession.modelName = result.modelName
            activeSession.recommendedQuestions = result.recommendedQuestions.isEmpty ? fallbackQuestions : result.recommendedQuestions
            post.analysisStatus = .completed
            post.latestAnalysisErrorMessage = nil
            post.analysisUpdatedAt = result.generatedAt
            try? modelContext.save()
            completionHapticTrigger += 1
            await loadAnalysisState()
        } catch is CancellationError {
            modelContext.delete(userMessage)
            modelContext.delete(pendingReply)
            activeSession.sessionStatus = .ready
            activeSession.lastMessageAt = Date()
            post.analysisStatus = .completed
            post.latestAnalysisErrorMessage = nil
            try? modelContext.save()
            await loadAnalysisState()
        } catch {
            pendingReply.text = "这次追问回复暂时失败。\n\n\(error.localizedDescription)"
            pendingReply.generationStatus = .failed
            activeSession.sessionStatus = .failed
            activeSession.failedAt = Date()
            activeSession.lastErrorMessage = error.localizedDescription
            post.analysisStatus = .failed
            post.latestAnalysisErrorMessage = error.localizedDescription
            post.analysisUpdatedAt = Date()
            try? modelContext.save()
            errorHapticTrigger += 1
            await loadAnalysisState()
        }
    }

    private func syncPostStatus(with session: VideoAnalysisSession) {
        switch session.sessionStatus {
        case .idle:
            post.analysisStatus = .idle
        case .generatingInitialMessage, .replying:
            post.analysisStatus = .processing
        case .ready, .archived:
            post.analysisStatus = .completed
        case .failed:
            post.analysisStatus = .failed
        }
    }

    private func cacheLegacyAnalysisSummary(
        using result: AIAnalysisConversationResult,
        selectedTag: VideoAnalysisTag
    ) {
        post.analysisStatus = .completed
        post.latestAnalysisHeadline = selectedTag.title
        post.latestAnalysisSummary = result.text.replacingOccurrences(of: "\n\n", with: " ")
        post.latestAnalysisFocus = nil
        post.latestRecommendation = result.recommendedQuestions.first ?? result.visibilityNote
        post.latestAnalysisErrorMessage = nil
        post.analysisModelName = result.modelName
        post.analysisUpdatedAt = result.generatedAt
    }

    private func sessionTone(for session: VideoAnalysisSession) -> StatusBadge.Tone {
        switch session.sessionStatus {
        case .idle:
            .warning
        case .generatingInitialMessage, .replying:
            .ai
        case .ready:
            .success
        case .failed:
            .error
        case .archived:
            .info
        }
    }

    private func retryAction(for message: VideoAnalysisMessage) -> (() -> Void)? {
        guard message.generationStatus == .failed else { return nil }
        switch message.messageType {
        case .initialAnalysis:
            let prompt = initialPrompt(before: message)
            return {
                guard !isBusy else { return }
                activeGenerationTask = Task {
                    await beginAnalysisSession(initialPrompt: prompt)
                }
            }
        case .followUpAnswer:
            guard
                let messageIndex = sessionMessages.firstIndex(where: { $0.id == message.id }),
                messageIndex > 0,
                sessionMessages[messageIndex - 1].sender == .user
            else { return nil }
            let question = sessionMessages[messageIndex - 1].text
            return { sendFollowUp(question) }
        default:
            return nil
        }
    }

    private func initialPrompt(before message: VideoAnalysisMessage) -> String? {
        guard let messageIndex = sessionMessages.firstIndex(where: { $0.id == message.id }),
              messageIndex > 0
        else {
            return nil
        }

        let previousMessage = sessionMessages[messageIndex - 1]
        guard previousMessage.sender == .user else { return nil }
        return previousMessage.text
    }

    private func conversationBubble(for message: VideoAnalysisMessage) -> some View {
        HStack(alignment: .top, spacing: theme.spacing.small) {
            if message.sender == .assistant || message.sender == .system {
                avatar(title: "AI", tint: theme.colors.ai, background: theme.colors.ai.opacity(0.14))
                bubbleBody(message: message, alignment: .leading, retryAction: retryAction(for: message))
            } else {
                Spacer(minLength: theme.spacing.xLarge)
                bubbleBody(message: message, alignment: .trailing)
                avatar(title: "你", tint: theme.colors.brandEmphasis, background: theme.colors.brand.opacity(0.14))
            }
        }
    }

    private func bubbleBody(
        message: VideoAnalysisMessage,
        alignment: HorizontalAlignment,
        retryAction: (() -> Void)? = nil
    ) -> some View {
        let isFailed = message.generationStatus == .failed
        let isPending = message.generationStatus == .pending
        let isUser = message.sender == .user

        return VStack(alignment: alignment, spacing: theme.spacing.xxxSmall) {
            if isPending {
                TypingIndicatorView()
                    .foregroundStyle(theme.colors.ai)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if isUser {
                Text(message.text.removingBidirectionalControlCharacters)
                    .font(theme.typography.body)
                    .foregroundStyle(isFailed ? theme.colors.error : theme.colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .environment(\.layoutDirection, .leftToRight)
                    .textSelection(.enabled)
            } else {
                Text(message.text.removingBidirectionalControlCharacters)
                    .font(theme.typography.body)
                    .foregroundStyle(isFailed ? theme.colors.error : theme.colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .environment(\.layoutDirection, .leftToRight)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if isFailed, let retryAction {
                Button(action: retryAction) {
                    Label("重试", systemImage: "arrow.clockwise")
                        .font(theme.typography.captionEmphasis)
                        .foregroundStyle(theme.colors.ai)
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .padding(.top, theme.spacing.xxxSmall)
            }
        }
        .padding(isUser
            ? EdgeInsets(top: theme.spacing.small, leading: theme.spacing.small, bottom: theme.spacing.small, trailing: theme.spacing.small)
            : EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
        .background(isUser ? theme.colors.brand.opacity(0.12) : .clear)
        .overlay {
            if isUser {
                RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous)
                    .stroke(
                        isFailed ? theme.colors.error.opacity(0.45) : theme.colors.brand.opacity(0.18),
                        lineWidth: theme.stroke.thin
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous))
    }

    private func avatar(title: String, tint: Color, background: Color) -> some View {
        Text(title)
            .font(theme.typography.captionEmphasis)
            .foregroundStyle(tint)
            .frame(width: 30, height: 30)
            .background(background)
            .clipShape(Circle())
    }

    private static func messageText(from result: AIAnalysisConversationResult) -> String {
        if let visibilityNote = result.visibilityNote, !visibilityNote.isEmpty {
            return "\(result.text)\n\n补充说明：\(visibilityNote)"
        }

        return result.text
    }
}

private struct TypingIndicatorView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< 3, id: \.self) { i in
                Circle()
                    .frame(width: 6, height: 6)
                    .opacity(animating ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.18),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
        .onDisappear { animating = false }
    }
}

// MARK: - Full Screen Player

private struct TrainingVideoPlayerScreen: View {
    @Environment(\.dismiss) private var dismiss

    let player: AVPlayer

    var body: some View {
        NavigationStack {
            VideoPlayer(player: player)
                .ignoresSafeArea()
                .background(Color.black)
                .navigationTitle("播放视频")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") {
                            dismiss()
                        }
                    }
                }
        }
    }
}
