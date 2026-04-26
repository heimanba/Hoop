import Foundation

struct AppConfiguration {
    let localAuthEmail: String
    let localAuthPassword: String
    let localUserDisplayName: String
    let localUserID: String

    static func load(bundle: Bundle = .main) throws -> AppConfiguration {
        let email = bundle.string(forInfoDictionaryKey: "LocalAuthEmail")?.trimmed
        let password = bundle.string(forInfoDictionaryKey: "LocalAuthPassword")?.trimmed
        let displayName = bundle.string(forInfoDictionaryKey: "LocalUserDisplayName")?.trimmed
        let userID = bundle.string(forInfoDictionaryKey: "LocalUserID")?.trimmed

        guard let email, !email.isEmpty, !email.contains("<your-local-auth-email>") else {
            throw ConfigurationError.missingLocalAuthEmail
        }

        guard let password, !password.isEmpty, !password.contains("<your-local-auth-password>") else {
            throw ConfigurationError.missingLocalAuthPassword
        }

        return AppConfiguration(
            localAuthEmail: email,
            localAuthPassword: password,
            localUserDisplayName: displayName?.nilIfEmpty ?? "Hoop 家长",
            localUserID: userID?.nilIfEmpty ?? "local-parent"
        )
    }
}

private extension Bundle {
    func string(forInfoDictionaryKey key: String) -> String? {
        object(forInfoDictionaryKey: key) as? String
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
