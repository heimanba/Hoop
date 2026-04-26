import SwiftUI

struct StatusBadge: View {
    @Environment(Theme.self) private var theme

    enum Tone {
        case brand
        case success
        case warning
        case error
        case info
        case ai
        case game
        case duel
    }

    let title: String
    let tone: Tone

    var body: some View {
        Text(title)
            .font(theme.typography.captionEmphasis)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, theme.spacing.xxSmall)
            .padding(.vertical, theme.spacing.xxxSmall)
            .background(backgroundColor)
            .clipShape(Capsule())
    }

    private var foregroundColor: Color {
        switch tone {
        case .brand: theme.colors.brandEmphasis
        case .success: theme.colors.success
        case .warning: theme.colors.warning
        case .error: theme.colors.error
        case .info: theme.colors.info
        case .ai: theme.colors.ai
        case .game: theme.colors.game
        case .duel: theme.colors.duel
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.12)
    }
}
