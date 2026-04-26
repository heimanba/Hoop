import SwiftUI

struct FollowUpChatSection: View {
    @Environment(Theme.self) private var theme

    let post: TrainingVideoPost
    @Binding var draft: String
    @Binding var messages: [VideoDetailChatMessage]
    @Binding var isSending: Bool

    let onSend: (String) -> Void

    var body: some View {
        HoopCard {
            VStack(alignment: .leading, spacing: theme.spacing.medium) {
                chatHeader
                messagesView
                suggestedQuestionsView
                composerView
            }
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(alignment: .top, spacing: theme.spacing.small) {
            Image(systemName: "message.badge.waveform.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.colors.ai)
                .frame(width: 36, height: 36)
                .background(theme.colors.ai.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: theme.spacing.xxxSmall) {
                Text("继续聊这条视频")
                    .font(theme.typography.title3)
                    .foregroundStyle(theme.colors.textPrimary)

                Text("保持 Chat 对话即可，适合继续问优先级、动作段、下次拍摄方式。")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
            }

            Spacer(minLength: theme.spacing.small)
        }
    }

    // MARK: - Messages (with auto-scroll P7)

    private var messagesView: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                messageBubble(starterAssistantMessage)

                ForEach(messages) { message in
                    messageBubble(message)
                        .id(message.id)
                }

                if isSending {
                    sendingIndicator
                        .id("sending-indicator")
                }
            }
            .padding(theme.spacing.small)
            .background(theme.colors.surfaceMuted.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous))
            .onChange(of: messages.count) {
                withAnimation(Animation.easeOut(duration: 0.22)) {
                    if let lastMessage = messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: isSending) {
                if isSending {
                    withAnimation(Animation.easeOut(duration: 0.22)) {
                        proxy.scrollTo("sending-indicator", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var sendingIndicator: some View {
        HStack(alignment: .top, spacing: theme.spacing.small) {
            ProgressView()
                .tint(theme.colors.ai)
                .padding(.top, theme.spacing.xxxSmall)

            VStack(alignment: .leading, spacing: theme.spacing.xxxSmall) {
                Text("AI")
                    .font(theme.typography.captionEmphasis)
                    .foregroundStyle(theme.colors.ai)

                Text("正在整理这条视频的追问回复…")
                    .font(theme.typography.callout)
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .padding(theme.spacing.small)
            .background(theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous))

            Spacer(minLength: theme.spacing.xLarge)
        }
    }

    // MARK: - Suggested Questions

    private var suggestedQuestionsView: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xSmall) {
            Text("推荐问题")
                .font(theme.typography.captionEmphasis)
                .foregroundStyle(theme.colors.textSecondary)

            ForEach(suggestedQuestions, id: \.self) { question in
                Button(question) {
                    onSend(question)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, theme.spacing.small)
                .padding(.vertical, theme.spacing.xSmall)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.colors.surfaceRaised)
                .overlay {
                    RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous)
                        .stroke(theme.colors.borderStrong, lineWidth: theme.stroke.thin)
                }
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous))
                .disabled(isSending)
                .accessibilityHint("点击发送这个问题给 AI")
            }
        }
    }

    // MARK: - Composer

    private var composerView: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xSmall) {
            Text("继续输入")
                .font(theme.typography.captionEmphasis)
                .foregroundStyle(theme.colors.textSecondary)

            HStack(alignment: .bottom, spacing: theme.spacing.xSmall) {
                TextField("例如：这条视频我最先该改哪一个动作？", text: $draft, axis: .vertical)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(2 ... 5)
                    .textInputAutocapitalization(.sentences)
                    .padding(.horizontal, theme.spacing.small)
                    .padding(.vertical, theme.spacing.small)
                    .background(theme.colors.surfaceRaised)
                    .overlay {
                        RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous)
                            .stroke(theme.colors.borderStrong, lineWidth: theme.stroke.thin)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous))

                Button {
                    onSend(draft)
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(theme.colors.textOnBrand)
                        .frame(width: theme.spacing.controlHeight, height: theme.spacing.controlHeight)
                        .background(isSendDisabled ? theme.colors.disabled : theme.colors.brand)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isSendDisabled)
                .accessibilityLabel("发送追问")
            }
        }
    }

    // MARK: - Helpers

    private var isSendDisabled: Bool {
        draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending
    }

    private var starterAssistantMessage: VideoDetailChatMessage {
        VideoDetailChatMessage(
            id: UUID(uuidString: "B4D7A703-5788-4DCA-9A54-61B53B0909A0") ?? UUID(),
            sender: .assistant,
            text: "我会基于这条视频的分析结果继续回答。你可以直接问我最先该改什么、问题大概出现在什么动作段，或者下次怎么拍更清楚。"
        )
    }

    private var suggestedQuestions: [String] {
        switch post.contentType {
        case .training:
            [
                "这条视频我最先该改什么？",
                "你说的问题大概出现在什么动作段？",
                "下次怎么拍会更方便你看清动作？"
            ]
        case .match:
            [
                "这条回合我最先该调整什么判断？",
                "你说的问题大概出现在哪个处理节点？",
                "下次补什么片段会更方便你继续分析？"
            ]
        case .duel:
            [
                "这段单挑里我最先该调整什么？",
                "你说的问题更像出现在进攻还是防守环节？",
                "下次补什么角度会更方便你继续分析？"
            ]
        }
    }

    // MARK: - Bubble

    private func messageBubble(_ message: VideoDetailChatMessage) -> some View {
        HStack(alignment: .top, spacing: theme.spacing.small) {
            if message.sender == .assistant {
                avatar(title: "AI", tint: theme.colors.ai, background: theme.colors.ai.opacity(0.14))
                bubbleBody(message: message, alignment: .leading)
                Spacer(minLength: theme.spacing.xLarge)
            } else {
                Spacer(minLength: theme.spacing.xLarge)
                bubbleBody(message: message, alignment: .trailing)
                avatar(title: "你", tint: theme.colors.brandEmphasis, background: theme.colors.brand.opacity(0.14))
            }
        }
    }

    private func bubbleBody(
        message: VideoDetailChatMessage,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: theme.spacing.xxxSmall) {
            Text(message.sender == .user ? "你" : "AI")
                .font(theme.typography.captionEmphasis)
                .foregroundStyle(message.sender == .user ? theme.colors.brandEmphasis : theme.colors.ai)

            Text(message.text)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
                .multilineTextAlignment(message.sender == .user ? .trailing : .leading)
        }
        .padding(theme.spacing.small)
        .background(message.sender == .user ? theme.colors.brand.opacity(0.12) : theme.colors.surfaceRaised)
        .overlay {
            RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous)
                .stroke(
                    message.sender == .user ? theme.colors.brand.opacity(0.18) : theme.colors.border,
                    lineWidth: theme.stroke.thin
                )
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
}
