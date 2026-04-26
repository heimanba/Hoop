import Foundation

struct AIAnalysisConfiguration: Sendable {
    let apiKey: String
    let baseURL: URL
    let model: String

    static func load(bundle: Bundle = .main) throws -> AIAnalysisConfiguration {
        let apiKey = try resolveRequired("DASHSCOPE_API_KEY", bundle: bundle)
        let baseURLString = resolveOptional("AI_ANALYSIS_BASE_URL", bundle: bundle)
            ?? "https://dashscope.aliyuncs.com/compatible-mode/v1"
        let model = resolveOptional("AI_ANALYSIS_MODEL", bundle: bundle) ?? "qwen3.6-plus"

        guard let baseURL = URL(string: baseURLString) else {
            throw AIAnalysisConfigurationError.invalidBaseURL(baseURLString)
        }

        return AIAnalysisConfiguration(
            apiKey: apiKey,
            baseURL: baseURL,
            model: model
        )
    }

    private static func resolveRequired(_ key: String, bundle: Bundle) throws -> String {
        if let value = resolveOptional(key, bundle: bundle) {
            return value
        }

        throw AIAnalysisConfigurationError.missingValue(key)
    }

    private static func resolveOptional(_ key: String, bundle: Bundle) -> String? {
        if let value = bundle.object(forInfoDictionaryKey: key) as? String {
            let trimmed = value.trimmed
            if !trimmed.isEmpty, !looksLikePlaceholder(trimmed) {
                return trimmed
            }
        }

        if let value = ProcessInfo.processInfo.environment[key]?.trimmed,
           !value.isEmpty,
           !looksLikePlaceholder(value) {
            return value
        }

        return nil
    }

    private static func looksLikePlaceholder(_ value: String) -> Bool {
        value.hasPrefix("<") || value.uppercased().hasPrefix("YOUR_")
    }
}

enum AIAnalysisConfigurationError: LocalizedError {
    case missingValue(String)
    case invalidBaseURL(String)

    var errorDescription: String? {
        switch self {
        case .missingValue(let key):
            "缺少 AI 配置：\(key)。请在 Config/Secrets.xcconfig 中补充该项。"
        case .invalidBaseURL(let value):
            "AI 分析服务地址无效：\(value)。请检查 Config/Secrets.xcconfig 中的 AI_ANALYSIS_BASE_URL。"
        }
    }
}
