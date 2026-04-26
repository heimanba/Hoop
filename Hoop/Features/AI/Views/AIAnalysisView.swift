import SwiftUI

struct AIAnalysisView: View {
    @Environment(Theme.self) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                SectionHeader(title: "AI 视频分析", subtitle: "重点动作、建议、历史对比")

                AIInsightCard(
                    title: "起步更顺，收球前还可以更低",
                    summary: "与上周相比，第一步启动延迟缩短，左右脚衔接更连贯。",
                    recommendation: "下次录制从侧前方拍摄，重点观察收球时肩膀是否先抬起。"
                )

                HoopCard {
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        Text("本周观察重点")
                            .font(theme.typography.title3)
                            .foregroundStyle(theme.colors.textPrimary)

                        analysisBullet("运球时眼睛抬得更早，场上判断在进步。")
                        analysisBullet("急停后重心还有点高，出手稳定性会受影响。")
                        analysisBullet("建议继续保留 10 到 15 秒短视频，方便自动对比。")
                    }
                }
            }
            .padding(.horizontal, theme.spacing.pageMargin)
            .padding(.vertical, theme.spacing.medium)
        }
        .navigationTitle("AI 分析")
        .hoopScreenBackground(theme)
    }

    private func analysisBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: theme.spacing.xxSmall) {
            Circle()
                .fill(theme.colors.ai)
                .frame(width: 6, height: 6)
                .padding(.top, theme.spacing.xxSmall)
            Text(text)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textSecondary)
        }
    }
}
