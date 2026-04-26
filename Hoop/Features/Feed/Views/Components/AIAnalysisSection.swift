import SwiftUI

// MARK: - Analysis Card Container (P3: eliminates repeated card styling)

private struct AnalysisCardStyle: ViewModifier {
    @Environment(Theme.self) private var theme

    func body(content: Content) -> some View {
        content
            .padding(theme.spacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous))
    }
}

private extension View {
    func analysisCardStyle() -> some View {
        modifier(AnalysisCardStyle())
    }
}

// MARK: - AI Analysis Section

struct AIAnalysisSection: View {
    @Environment(Theme.self) private var theme

    let post: TrainingVideoPost
    let onRunAnalysis: (TrainingVideoPost) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.medium) {
            SectionHeader(
                title: "AI 分析",
                subtitle: "分析结果会绑定在这条视频上，方便边看边回顾"
            )

            analysisReportCard
        }
    }

    // MARK: - Report Card

    private var analysisReportCard: some View {
        HoopCard {
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                HStack(alignment: .top, spacing: theme.spacing.small) {
                    VStack(alignment: .leading, spacing: theme.spacing.xxxSmall) {
                        Text("最新分析结果")
                            .font(theme.typography.title3)
                            .foregroundStyle(theme.colors.textPrimary)

                        Text("先快速看结论，再继续追问细节。")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.textSecondary)
                    }

                    Spacer(minLength: theme.spacing.small)

                    StatusBadge(title: post.analysisStatus.title, tone: post.analysisStatus.badgeTone)
                }

                analysisContent
                actionArea
            }
        }
    }

    // MARK: - Content by Status

    @ViewBuilder
    private var analysisContent: some View {
        switch post.analysisStatus {
        case .idle:
            placeholderCard(
                title: "还没有分析结果",
                message: pendingAnalysisMessage
            )

        case .processing:
            processingCard

        case .completed:
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                if let headline = post.displayAnalysisHeadline {
                    resultCard(title: "分析标题", body: headline)
                }

                resultCard(
                    title: "动作总结",
                    body: post.latestAnalysisSummary ?? completedFallbackSummary
                )

                if !post.latestAnalysisFocusPoints.isEmpty {
                    focusCard(points: post.latestAnalysisFocusPoints)
                }

                resultCard(
                    title: "改进建议",
                    body: post.latestRecommendation ?? completedFallbackRecommendation
                )
            }

        case .failed:
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                placeholderCard(
                    title: "分析暂时失败",
                    message: post.latestAnalysisErrorMessage ?? "当前分析链路暂时不可用，建议稍后重试这条视频。"
                )

                if let summary = post.latestAnalysisSummary, !summary.isEmpty {
                    resultCard(title: "上次动作总结", body: summary)
                }

                if !post.latestAnalysisFocusPoints.isEmpty {
                    focusCard(points: post.latestAnalysisFocusPoints)
                }

                if let recommendation = post.latestRecommendation, !recommendation.isEmpty {
                    resultCard(title: "上次改进建议", body: recommendation)
                }
            }
        }
    }

    // MARK: - Action Area

    @ViewBuilder
    private var actionArea: some View {
        if let actionTitle = post.analysisStatus.actionTitle {
            Button(actionTitle, systemImage: "sparkles") {
                onRunAnalysis(post)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    // MARK: - Card Variants

    private var processingCard: some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            HStack(spacing: theme.spacing.small) {
                ProgressView()
                    .tint(theme.colors.ai)
                    .scaleEffect(1.1)

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI 正在分析这条视频")
                        .font(theme.typography.bodyEmphasis)
                        .foregroundStyle(theme.colors.textPrimary)

                    Text(processingMessage)
                        .font(theme.typography.callout)
                        .foregroundStyle(theme.colors.textSecondary)
                }
            }

            Text("分析完成后结果会自动呈现在这里。")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textTertiary)
        }
        .analysisCardStyle()
    }

    private func resultCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xxSmall) {
            Text(title)
                .font(theme.typography.captionEmphasis)
                .foregroundStyle(theme.colors.textSecondary)

            Text(body)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
        }
        .analysisCardStyle()
    }

    private func focusCard(points: [String]) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xxSmall) {
            Text("观察重点")
                .font(theme.typography.captionEmphasis)
                .foregroundStyle(theme.colors.textSecondary)

            VStack(alignment: .leading, spacing: theme.spacing.xSmall) {
                ForEach(points, id: \.self) { point in
                    HStack(alignment: .top, spacing: theme.spacing.xxSmall) {
                        Circle()
                            .fill(theme.colors.ai)
                            .frame(width: 6, height: 6)
                            .padding(.top, theme.spacing.xxSmall)

                        Text(point)
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colors.textPrimary)
                    }
                }
            }
        }
        .analysisCardStyle()
    }

    private func placeholderCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xxSmall) {
            Text(title)
                .font(theme.typography.bodyEmphasis)
                .foregroundStyle(theme.colors.textPrimary)

            Text(message)
                .font(theme.typography.callout)
                .foregroundStyle(theme.colors.textSecondary)
        }
        .analysisCardStyle()
    }

    // MARK: - Text Helpers

    private var pendingAnalysisMessage: String {
        switch post.contentType {
        case .training:
            "还没有分析结果。开始 AI 分析后，这里会先输出动作总结，再给出下一步训练建议。"
        case .match:
            "还没有分析结果。开始 AI 分析后，这里会结合比赛片段输出回合判断和后续建议。"
        case .duel:
            "还没有分析结果。开始 AI 分析后，这里会结合单挑片段输出对抗选择和后续建议。"
        }
    }

    private var processingMessage: String {
        switch post.contentType {
        case .training:
            "系统正在整理动作节奏、重心控制和衔接建议。"
        case .match:
            "系统正在整理回合判断、处理选择和衔接建议。"
        case .duel:
            "系统正在整理对抗判断、处理选择和节奏建议。"
        }
    }

    private var completedFallbackSummary: String {
        switch post.contentType {
        case .training:
            "这条训练视频的总结已经生成，后续可以继续结合更多连续动作做对比。"
        case .match:
            "这条比赛视频的总结已经生成，后续可以继续结合完整回合做判断。"
        case .duel:
            "这条单挑视频的总结已经生成，后续可以继续结合完整对抗回合做判断。"
        }
    }

    private var completedFallbackRecommendation: String {
        switch post.contentType {
        case .training:
            "建议继续补充同动作的连续拍摄，帮助后续对比动作细节。"
        case .match:
            "建议继续补充更完整的比赛片段，帮助后续沉淀比赛场景建议。"
        case .duel:
            "建议继续补充更完整的单挑片段，帮助后续沉淀对抗场景建议。"
        }
    }

}
