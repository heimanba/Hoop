import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(Theme.self) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(theme.typography.bodyEmphasis)
            .foregroundStyle(theme.colors.textOnBrand)
            .frame(maxWidth: .infinity)
            .frame(height: theme.spacing.controlHeight)
            .background(theme.colors.brand)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous))
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(theme.motion.quick, value: configuration.isPressed)
    }
}
