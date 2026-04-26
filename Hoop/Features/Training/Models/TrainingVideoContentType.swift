import Foundation

enum TrainingVideoContentType: String, CaseIterable, Codable {
    case training
    case match
    case duel

    var title: String {
        switch self {
        case .training:
            "训练"
        case .match:
            "比赛"
        case .duel:
            "单挑"
        }
    }

    var badgeTone: StatusBadge.Tone {
        switch self {
        case .training:
            .brand
        case .match:
            .game
        case .duel:
            .duel
        }
    }

    var uploadButtonTitle: String {
        switch self {
        case .training:
            "上传训练视频"
        case .match:
            "上传比赛视频"
        case .duel:
            "上传单挑视频"
        }
    }

    var analysisStrategy: AnalysisStrategy {
        switch self {
        case .training:
            AnalysisStrategy(
                roleDescription: "把这条视频当作训练样本，优先识别动作完成质量和重复稳定性。",
                focusAreas: [
                    "先看动作链条是否完整，发力顺序是否清楚。",
                    "关注节奏、重心、发力和落点/终点控制是否连贯。",
                    "优先指出最影响训练质量、最值得先改的 1 到 2 个问题。"
                ],
                avoidances: [
                    "不要把训练视频分析成正式比赛回合复盘。",
                    "不要泛泛而谈心态、拼劲或结果，重点放在动作执行。"
                ],
                summaryGuidance: "总结重点放在动作质量、重复稳定性和最关键的纠正点。",
                recommendationGuidance: "建议优先给出可执行的训练修正、补拍角度或下次练习重点。",
                questionGuidance: "推荐追问偏向怎么练、先改哪里、还需要补拍什么角度。"
            )
        case .match:
            AnalysisStrategy(
                roleDescription: "把这条视频当作比赛片段，优先复盘回合决策和处理结果。",
                focusAreas: [
                    "先看回合目标是否明确，处理球和出动作的时机是否合理。",
                    "关注空间利用、出手选择、协防识别和决策结果。",
                    "结合场上可见信息说明更好的下一拍选择，但不要脱离画面臆测战术。"
                ],
                avoidances: [
                    "不要把比赛视频分析成纯动作训练分解。",
                    "不要只评价进没进，重点解释选择为什么好或不好。"
                ],
                summaryGuidance: "总结重点放在回合判断、时机和空间处理是否合理。",
                recommendationGuidance: "建议优先给出下一次遇到类似回合时的选择和处理原则。",
                questionGuidance: "推荐追问偏向这一回合还有什么选择、时机为什么不对、空间哪里没用好。"
            )
        case .duel:
            AnalysisStrategy(
                roleDescription: "把这条视频当作一对一攻防片段，优先分析对位判断和创造优势的过程。",
                focusAreas: [
                    "先看进攻或防守一拍的试探、重心变化和启动是否占到先机。",
                    "关注对位距离、脚步应对、变向/变速时机和空间创造方式。",
                    "说明这一对位里最关键的胜负手，以及下一拍还能怎样扩大优势或止损。"
                ],
                avoidances: [
                    "不要把单挑视频写成完整五人比赛复盘。",
                    "不要脱离一对一攻防语境去讨论与画面无关的团队战术。"
                ],
                summaryGuidance: "总结重点放在一对一对位中的攻防判断、脚步应对和空间创造。",
                recommendationGuidance: "建议优先给出下一次单挑时可直接执行的试探、脚步或出手应对。",
                questionGuidance: "推荐追问偏向这类对位怎么打、脚步怎么应对、下一拍怎样创造更大优势。"
            )
        }
    }
}

extension TrainingVideoContentType {
    struct AnalysisStrategy {
        let roleDescription: String
        let focusAreas: [String]
        let avoidances: [String]
        let summaryGuidance: String
        let recommendationGuidance: String
        let questionGuidance: String
    }
}
