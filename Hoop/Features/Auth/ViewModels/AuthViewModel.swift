import Foundation
import SwiftData

@MainActor
@Observable
final class AuthViewModel {
    enum AuthState: Equatable {
        case loading
        case signedOut
        case signedIn(AuthenticatedUser)
        case configurationError(String)
    }

    private(set) var state: AuthState = .loading
    private(set) var isWorking = false
    var message: String?

    private let configuration: AppConfiguration?
    private static let sessionKey = "current-user"

    init() {
        do {
            configuration = try AppConfiguration.load()
        } catch {
            configuration = nil
            state = .configurationError(Self.safeMessage(for: error))
        }
    }

    var configuredEmail: String? {
        configuration?.localAuthEmail
    }

    func validateDevicePassword(_ password: String) -> Bool {
        guard let configuration else { return false }
        return password == configuration.localAuthPassword
    }

    func restoreSession(from records: [AuthSessionRecord]) {
        guard configuration != nil else { return }

        if let record = records.first(where: { $0.key == Self.sessionKey }) {
            state = .signedIn(
                AuthenticatedUser(
                    id: record.userID,
                    email: record.email,
                    displayName: record.displayName
                )
            )
        } else {
            state = .signedOut
        }
    }

    func signIn(email: String, password: String, context: ModelContext) {
        guard let configuration else {
            message = "本地登录配置不可用。"
            return
        }

        isWorking = true
        defer { isWorking = false }

        let normalizedEmail = email.trimmed.lowercased()
        let normalizedConfiguredEmail = configuration.localAuthEmail.lowercased()

        guard normalizedEmail == normalizedConfiguredEmail,
              password == configuration.localAuthPassword else {
            state = .signedOut
            message = "邮箱或密码不正确。"
            return
        }

        let user = AuthenticatedUser(
            id: configuration.localUserID,
            email: configuration.localAuthEmail,
            displayName: configuration.localUserDisplayName
        )
        message = nil

        do {
            try upsertSession(for: user, in: context)
            state = .signedIn(user)
            message = "登录成功。"
        } catch {
            message = Self.safeMessage(for: error)
        }
    }

    func signOut(context: ModelContext) {
        isWorking = true
        defer { isWorking = false }

        do {
            try clearSession(in: context)
            state = .signedOut
            message = "已退出登录。"
        } catch {
            message = Self.safeMessage(for: error)
        }
    }

    private func upsertSession(for user: AuthenticatedUser, in context: ModelContext) throws {
        let sessionKey = Self.sessionKey
        let descriptor = FetchDescriptor<AuthSessionRecord>(
            predicate: #Predicate<AuthSessionRecord> { $0.key == sessionKey }
        )

        if let existingRecord = try context.fetch(descriptor).first {
            existingRecord.userID = user.id
            existingRecord.email = user.email
            existingRecord.displayName = user.displayName
            existingRecord.signedInAt = .now
        } else {
            context.insert(
                AuthSessionRecord(
                    key: Self.sessionKey,
                    userID: user.id,
                    email: user.email,
                    displayName: user.displayName,
                    signedInAt: .now
                )
            )
        }

        try context.save()
    }

    private func clearSession(in context: ModelContext) throws {
        let descriptor = FetchDescriptor<AuthSessionRecord>()
        try context.fetch(descriptor).forEach(context.delete)
        try context.save()
    }

    private static func safeMessage(for error: Error) -> String {
        if let configurationError = error as? ConfigurationError {
            return configurationError.localizedDescription
        }

        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            return description
        }

        let text = error.localizedDescription
        if text.isEmpty {
            return "出错了，请重试。"
        }

        return text
    }
}
