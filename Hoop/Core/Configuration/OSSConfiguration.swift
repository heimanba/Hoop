import Foundation

struct OSSConfiguration: Sendable {
    let accessKeyID: String
    let accessKeySecret: String
    let bucket: String
    let endpoint: String
    let region: String
    let uploadDirectory: String
    let publicBaseURL: String?

    static func load(bundle: Bundle = .main) throws -> OSSConfiguration {
        OSSConfiguration(
            accessKeyID: try resolve("OSS_ACCESS_KEY_ID", bundle: bundle),
            accessKeySecret: try resolve("OSS_ACCESS_KEY_SECRET", bundle: bundle),
            bucket: try resolve("OSS_BUCKET", bundle: bundle),
            endpoint: try resolve("OSS_ENDPOINT", bundle: bundle),
            region: try resolve("OSS_REGION", bundle: bundle),
            uploadDirectory: resolveOptional("OSS_UPLOAD_DIR", bundle: bundle) ?? "training-videos",
            publicBaseURL: resolveOptional("OSS_PUBLIC_BASE_URL", bundle: bundle)
        )
    }

    private static func resolve(_ key: String, bundle: Bundle) throws -> String {
        if let value = resolveOptional(key, bundle: bundle) {
            return value
        }

        throw OSSConfigurationError.missingValue(key)
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

enum OSSConfigurationError: LocalizedError {
    case missingValue(String)

    var errorDescription: String? {
        switch self {
        case .missingValue(let key):
            "缺少 OSS 配置：\(key)。请在 Config/Secrets.xcconfig 中补充该项。"
        }
    }
}
