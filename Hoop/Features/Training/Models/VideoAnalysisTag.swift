import Foundation

enum VideoAnalysisTag: String, CaseIterable, Codable {
    case trainingForm
    case trainingRhythm
    case trainingForceBalance
    case trainingStability
    case trainingPriorityFix
    case matchDecision
    case matchTiming
    case matchSpacing
    case matchShotSelection
    case matchDefensiveRead

    var title: String {
        switch self {
        case .trainingForm:
            "动作基础"
        case .trainingRhythm:
            "节奏衔接"
        case .trainingForceBalance:
            "发力与重心"
        case .trainingStability:
            "稳定性"
        case .trainingPriorityFix:
            "优先纠正点"
        case .matchDecision:
            "回合判断"
        case .matchTiming:
            "处理时机"
        case .matchSpacing:
            "空间利用"
        case .matchShotSelection:
            "出手选择"
        case .matchDefensiveRead:
            "防守阅读"
        }
    }

    var promptHint: String {
        switch self {
        case .trainingForm:
            "动作是否稳定，链条是否清楚"
        case .trainingRhythm:
            "节奏和衔接是否合理，停顿是否多余"
        case .trainingForceBalance:
            "发力路径和重心控制是否协调"
        case .trainingStability:
            "重复动作时哪里容易失衡"
        case .trainingPriorityFix:
            "最该先改的一个问题是什么"
        case .matchDecision:
            "回合中判断和决策是否合理"
        case .matchTiming:
            "处理球和出动作的时机是否合适"
        case .matchSpacing:
            "站位和推进路径是否合理"
        case .matchShotSelection:
            "出手选择是否合理，有没有更好方案"
        case .matchDefensiveRead:
            "对防守的识别和应对是否到位"
        }
    }

    func promptHint(for contentType: TrainingVideoContentType) -> String {
        switch contentType {
        case .training:
            switch self {
            case .trainingForm:
                "重点看动作链条是否完整、发力顺序是否清楚。"
            case .trainingRhythm:
                "重点看启动、衔接和停顿是否顺畅，有没有多余节奏损耗。"
            case .trainingForceBalance:
                "重点看发力路径、身体重心和上下肢协同是否稳定。"
            case .trainingStability:
                "重点看重复动作时是否容易晃动、偏移或失去控制。"
            case .trainingPriorityFix:
                "重点找出最影响训练质量、最该先纠正的那个问题。"
            case .matchDecision:
                "如果画面更像训练情境，也只从动作执行选择是否合适的角度轻量补充。"
            case .matchTiming:
                "如果画面更像训练情境，也只从出动作时机是否顺畅的角度轻量补充。"
            case .matchSpacing:
                "如果画面更像训练情境，也只从身体与球位关系、移动路径是否合理的角度轻量补充。"
            case .matchShotSelection:
                "如果画面更像训练情境，也只从终结动作选择是否匹配训练目标的角度轻量补充。"
            case .matchDefensiveRead:
                "如果画面更像训练情境，也只从对假想防守反应的准备是否合理的角度轻量补充。"
            }
        case .match:
            switch self {
            case .trainingForm:
                "如果画面出现明显技术问题，可补充动作基础如何影响本回合结果。"
            case .trainingRhythm:
                "重点看处理球和出动作的节奏是否帮你创造了优势。"
            case .trainingForceBalance:
                "重点看身体对抗下的发力和重心控制是否支撑了这次处理。"
            case .trainingStability:
                "重点看高速或对抗下动作是否还能保持稳定和可控。"
            case .trainingPriorityFix:
                "重点找出最影响回合结果、最该优先修正的决策或执行问题。"
            case .matchDecision:
                "重点看你在这个回合里的判断和选择是否合理。"
            case .matchTiming:
                "重点看持球、突破、传导或出手的时机是否合适。"
            case .matchSpacing:
                "重点看站位、推进路径和空间利用是否为下一步创造了条件。"
            case .matchShotSelection:
                "重点看出手或终结选择是否匹配当时的防守和空间。"
            case .matchDefensiveRead:
                "重点看你对防守站位、协防和补位的识别是否到位。"
            }
        case .duel:
            switch self {
            case .trainingForm:
                "重点看动作基础是否足以支撑一对一里的第一拍优势。"
            case .trainingRhythm:
                "重点看试探、变速和连续动作节奏是否打乱了对位防守。"
            case .trainingForceBalance:
                "重点看对抗中的发力、沉肩、急停和重心转换是否占优。"
            case .trainingStability:
                "重点看一对一连续变向或对抗下动作是否还能稳定完成。"
            case .trainingPriorityFix:
                "重点找出最影响这组一对一攻防结果、最该先修正的问题。"
            case .matchDecision:
                "重点看一对一里试探、突破、收球或终结的判断是否合理。"
            case .matchTiming:
                "重点看启动、变向、急停和出手的时机是否抓住了对位空档。"
            case .matchSpacing:
                "重点看如何利用对位距离、落脚点和横向空间创造优势。"
            case .matchShotSelection:
                "重点看终结方式和出手选择是否真正压过了当前防守。"
            case .matchDefensiveRead:
                "重点看你对对手重心、脚步和封堵意图的识别是否及时。"
            }
        }
    }

    static func tags(for contentType: TrainingVideoContentType) -> [VideoAnalysisTag] {
        switch contentType {
        case .training:
            [
                .trainingForm,
                .trainingRhythm,
                .trainingForceBalance,
                .trainingStability,
                .trainingPriorityFix
            ]
        case .match:
            [
                .matchDecision,
                .matchTiming,
                .matchSpacing,
                .matchShotSelection,
                .matchDefensiveRead
            ]
        case .duel:
            [
                .matchDecision,
                .matchTiming,
                .matchSpacing,
                .matchShotSelection,
                .matchDefensiveRead
            ]
        }
    }

    static func defaultTag(for contentType: TrainingVideoContentType) -> VideoAnalysisTag {
        tags(for: contentType).first ?? .trainingForm
    }
}
