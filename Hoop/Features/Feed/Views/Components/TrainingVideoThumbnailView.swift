import SwiftUI
import UIKit

struct TrainingVideoThumbnailView: View {
    @Environment(Theme.self) private var theme

    let post: TrainingVideoPost
    let showsCompactBadges: Bool
    let mediaAspectRatio: CGFloat

    init(
        post: TrainingVideoPost,
        showsCompactBadges: Bool,
        mediaAspectRatio: CGFloat? = nil
    ) {
        self.post = post
        self.showsCompactBadges = showsCompactBadges
        self.mediaAspectRatio = mediaAspectRatio ?? 16.0 / 9.0
    }

    var body: some View {
        Color.clear
            .aspectRatio(mediaAspectRatio, contentMode: .fit)
            .overlay {
                thumbnailBackground
            }
            .overlay {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.08),
                        Color.black.opacity(0.32)
                    ],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
            .overlay {
                Image(systemName: "play.fill")
                    .font(.system(size: showsCompactBadges ? 26 : 32, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(showsCompactBadges ? theme.spacing.small : theme.spacing.medium)
                    .background(.black.opacity(0.34))
                    .clipShape(Circle())
            }
            .overlay(alignment: .bottom) {
                HStack(alignment: .bottom) {
                    StatusBadge(title: post.contentType.title, tone: post.contentType.badgeTone)
                    Spacer()

                    if let durationText {
                        mediaPill(durationText)
                    }
                }
                .padding(theme.spacing.small)
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous))
    }

    @ViewBuilder
    private var thumbnailBackground: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .clipped()
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        theme.colors.surfaceMuted,
                        theme.colors.fillStrong,
                        overlayAccentColor
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: backgroundSymbolName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(theme.colors.textTertiary)
            }
        }
    }

    private var image: UIImage? {
        guard let thumbnailURL = post.localThumbnailURL,
              let data = try? Data(contentsOf: thumbnailURL),
              let image = UIImage(data: data) else {
            return nil
        }

        return image
    }

    private var durationText: String? {
        guard let durationSeconds = post.durationSeconds,
              durationSeconds.isFinite,
              durationSeconds > 0 else {
            return nil
        }

        let totalSeconds = Int(durationSeconds.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var overlayAccentColor: Color {
        switch post.contentType {
        case .training:
            theme.colors.brand.opacity(0.18)
        case .match:
            theme.colors.game.opacity(0.22)
        case .duel:
            theme.colors.duel.opacity(0.22)
        }
    }

    private var backgroundSymbolName: String {
        switch post.contentType {
        case .training:
            "figure.basketball"
        case .match:
            "sportscourt.fill"
        case .duel:
            "person.2.fill"
        }
    }

    private func mediaPill(_ title: String) -> some View {
        Text(title)
            .font(theme.typography.captionEmphasis)
            .foregroundStyle(Color.white)
            .padding(.horizontal, theme.spacing.xxSmall)
            .padding(.vertical, theme.spacing.xxxSmall)
            .background(.black.opacity(0.42))
            .clipShape(Capsule())
    }
}
