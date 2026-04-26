import SwiftUI

struct MatchCenterView: View {
    @Environment(Theme.self) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                SectionHeader(title: "比赛与单挑", subtitle: "事件记录、表现摘要、关键瞬间")

                HoopCard {
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        HStack {
                            StatusBadge(title: "比赛", tone: .game)
                            StatusBadge(title: "单挑", tone: .duel)
                        }

                        Text("周末对抗赛")
                            .font(theme.typography.title3)
                            .foregroundStyle(theme.colors.textPrimary)

                        Text("突破后的第一步更坚决，回防速度比上场更快。")
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colors.textSecondary)

                        HStack(spacing: theme.spacing.xSmall) {
                            MetricTile(title: "篮板", value: "6", subtitle: "抢位更主动", tone: theme.colors.game)
                            MetricTile(title: "单挑胜率", value: "67%", subtitle: "较上周 +9%", tone: theme.colors.duel)
                        }
                    }
                }

                SectionHeader(title: "关键瞬间", subtitle: "让比赛记录能继续服务训练")

                VStack(spacing: theme.spacing.small) {
                    highlightRow(title: "第二节 03:12", detail: "补防后完成抢断，脚步移动很干净。")
                    highlightRow(title: "第三节 01:48", detail: "突破结束时身体有点后仰，落点可以更稳。")
                }
            }
            .padding(.horizontal, theme.spacing.pageMargin)
            .padding(.vertical, theme.spacing.medium)
        }
        .navigationTitle("比赛")
        .hoopScreenBackground(theme)
    }

    private func highlightRow(title: String, detail: String) -> some View {
        HoopCard {
            VStack(alignment: .leading, spacing: theme.spacing.xxSmall) {
                Text(title)
                    .font(theme.typography.captionEmphasis)
                    .foregroundStyle(theme.colors.game)
                Text(detail)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textPrimary)
            }
        }
    }
}
