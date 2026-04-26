import Foundation

enum ConfigurationError: LocalizedError {
    case missingLocalAuthEmail
    case missingLocalAuthPassword

    var errorDescription: String? {
        switch self {
        case .missingLocalAuthEmail:
            "登录邮箱缺失。请在 Config/Secrets.xcconfig 中设置 AUTH_EMAIL。"
        case .missingLocalAuthPassword:
            "登录密码缺失。请在 Config/Secrets.xcconfig 中设置 AUTH_PASSWORD。"
        }
    }
}
