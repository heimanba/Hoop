import SwiftUI

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(Theme.self) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(theme.typography.bodyEmphasis)
            .foregroundStyle(theme.colors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: theme.spacing.controlHeight)
            .background(theme.colors.surfaceRaised)
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous)
                    .stroke(theme.colors.borderStrong, lineWidth: theme.stroke.thin)
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous))
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(theme.motion.quick, value: configuration.isPressed)
    }
}
