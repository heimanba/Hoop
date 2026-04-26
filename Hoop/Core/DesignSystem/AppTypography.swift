import SwiftUI

struct AppTypography {
    let display = Font.system(.largeTitle, design: .rounded, weight: .bold)
    let title1 = Font.system(.title, design: .rounded, weight: .bold)
    let title2 = Font.system(.title2, design: .rounded, weight: .semibold)
    let title3 = Font.system(.title3, design: .rounded, weight: .semibold)
    let body = Font.system(.body, design: .rounded)
    let bodyEmphasis = Font.system(.body, design: .rounded, weight: .semibold)
    let callout = Font.system(.callout, design: .rounded)
    let caption = Font.system(.caption, design: .rounded)
    let captionEmphasis = Font.system(.caption, design: .rounded, weight: .semibold)
    let metricLarge = Font.system(size: 30, weight: .bold, design: .rounded)
    let metricMedium = Font.system(size: 22, weight: .bold, design: .rounded)
}
