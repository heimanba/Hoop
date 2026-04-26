import SwiftUI

struct TrainingVideoPostCard: View {
    @Environment(Theme.self) private var theme

    let post: TrainingVideoPost
    let memberProfile: LocalUserProfile?
    let showsMember: Bool
    var onOpenDetail: ((TrainingVideoPost) -> Void)?
    var onRunAnalysis: ((TrainingVideoPost) -> Void)?
    var onDelete: ((TrainingVideoPost) -> Void)?
    @State private var isPresentingDeleteConfirmation = false

    var body: some View {
        HoopCard {
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                TrainingVideoThumbnailView(post: post, showsCompactBadges: true)

                VStack(alignment: .leading, spacing: theme.spacing.xxSmall) {
                    if showsMember, let memberProfile {
                        Text("\(memberProfile.avatarEmoji) \(memberProfile.displayName)")
                            .font(theme.typography.captionEmphasis)
                            .foregroundStyle(theme.colors.textSecondary)
                    }

                    Text(postTitle)
                        .font(theme.typography.title3)
                        .foregroundStyle(theme.colors.textPrimary)
                        .lineLimit(1)

                    HStack(alignment: .firstTextBaseline, spacing: theme.spacing.xxSmall) {
                        Text(uploadedTimeText)
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.textSecondary)

                        Text("·")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.textTertiary)

                        Text(post.analysisStatus.title)
                            .font(theme.typography.captionEmphasis)
                            .foregroundStyle(statusColor)
                    }

                    if let summaryText {
                        Text(summaryText)
                            .font(theme.typography.callout)
                            .foregroundStyle(theme.colors.textSecondary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: theme.spacing.xSmall) {
                    StatusBadge(title: post.analysisStatus.title, tone: post.analysisStatus.badgeTone)
                    Spacer()
                    if let onRunAnalysis, let actionTitle = post.analysisStatus.actionTitle {
                        Button {
                            onRunAnalysis(post)
                        } label: {
                            Label(compactActionTitle(for: actionTitle), systemImage: "sparkles")
                                .font(theme.typography.captionEmphasis)
                                .foregroundStyle(theme.colors.brandEmphasis)
                                .padding(.horizontal, theme.spacing.xxSmall)
                                .padding(.vertical, theme.spacing.xxxSmall)
                                .background(theme.colors.brand.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    } else if post.analysisStatus.actionTitle == nil {
                        HStack(spacing: theme.spacing.xxSmall) {
                            ProgressView()
                                .tint(theme.colors.ai)
                            Text("分析中")
                                .font(theme.typography.captionEmphasis)
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onOpenDetail?(post)
        }
        .contextMenu {
            if onDelete != nil {
                Button("删除视频动态", role: .destructive) {
                    isPresentingDeleteConfirmation = true
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
            }
        } message: {
            Text("本地记录和缓存将被移除，已上传的视频文件不会被删除。")
        }
    }

    private var postTitle: String {
        if let headline = post.displayAnalysisHeadline {
            return headline
        }

        if let drillName = post.drillName, !drillName.isEmpty {
            return drillName
        }

        return post.fileName
    }

    private var uploadedTimeText: String {
        Self.timeFormatter.string(from: post.uploadedAt)
    }

    private var summaryText: String? {
        if let summary = post.latestAnalysisSummary, !summary.isEmpty {
            return summary
        }

        if let errorMessage = post.latestAnalysisErrorMessage, !errorMessage.isEmpty {
            return errorMessage
        }

        return nil
    }

    private var statusColor: Color {
        switch post.analysisStatus.badgeTone {
        case .brand:
            theme.colors.brandEmphasis
        case .success:
            theme.colors.success
        case .warning:
            theme.colors.warning
        case .error:
            theme.colors.error
        case .info:
            theme.colors.info
        case .ai:
            theme.colors.ai
        case .game:
            theme.colors.game
        case .duel:
            theme.colors.duel
        }
    }

    private func compactActionTitle(for title: String) -> String {
        switch title {
        case "开始 AI 分析":
            "分析"
        case "重新分析":
            "重试"
        default:
            title
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}
