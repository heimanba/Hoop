import Foundation

enum VideoAnalysisStatus: String, Codable {
    case idle
    case processing
    case completed
    case failed

    var title: String {
        switch self {
        case .idle:
            "待分析"
        case .processing:
            "分析中"
        case .completed:
            "已完成"
        case .failed:
            "失败"
        }
    }

    var badgeTone: StatusBadge.Tone {
        switch self {
        case .idle:
            .warning
        case .processing:
            .ai
        case .completed:
            .success
        case .failed:
            .error
        }
    }

    var actionTitle: String? {
        switch self {
        case .idle:
            "开始 AI 分析"
        case .processing:
            nil
        case .completed, .failed:
            "重新分析"
        }
    }
}
