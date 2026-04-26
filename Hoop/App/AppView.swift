import SwiftUI

struct AppView: View {
    @Environment(Theme.self) private var theme

    var body: some View {
        AuthRootView()
            .tint(theme.colors.brand)
            .hoopScreenBackground(theme)
    }
}

#Preview {
    AppView()
        .environment(Theme())
}
