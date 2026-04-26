import SwiftUI

struct AppMotion {
    let quick = Animation.easeOut(duration: 0.16)
    let standard = Animation.easeInOut(duration: 0.22)
    let emphasis = Animation.spring(response: 0.28, dampingFraction: 0.86)
}
