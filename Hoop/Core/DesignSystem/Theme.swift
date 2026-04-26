import Observation
import SwiftUI

@MainActor
@Observable
final class Theme {
    let colors = AppColor()
    let spacing = AppSpacing()
    let radius = AppRadius()
    let stroke = AppStroke()
    let shadow = AppShadow()
    let motion = AppMotion()
    let typography = AppTypography()
}
