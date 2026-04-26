import SwiftUI

extension View {
    func hoopScreenBackground(_ theme: Theme) -> some View {
        background(theme.colors.background.ignoresSafeArea())
    }
}
