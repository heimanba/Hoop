import AVFoundation
import AVKit
import SwiftUI
import UIKit

// Pure AVPlayerLayer view — renders only video pixels, zero native controls or overlays.
private struct InlineVideoPlayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ view: PlayerLayerView, context: Context) {
        if view.playerLayer.player !== player {
            view.playerLayer.player = player
        }
    }

    final class PlayerLayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }
    }
}

struct VideoPlayerSection: View {
    @Environment(Theme.self) private var theme

    let post: TrainingVideoPost
    let memberProfile: LocalUserProfile?
    let playbackController: VideoPlaybackController

    var body: some View {
        HoopCard {
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                videoPlayerSurface

                VStack(alignment: .leading, spacing: theme.spacing.xSmall) {
                    // Text(postTitle)
                    //     .font(theme.typography.title3)
                    //     .foregroundStyle(theme.colors.textPrimary)
                    //     .lineLimit(2)

                    Text("点击播放，围绕这条视频和 AI 教练展开分析")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textSecondary)

                    videoMetadataRow
                }
            }
        }
    }

    // MARK: - Video Player Surface

    @ViewBuilder
    private var videoPlayerSurface: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .frame(maxWidth: .infinity)
                .aspectRatio(effectiveVideoAspectRatio, contentMode: .fit)
                .frame(
                    minHeight: isPortraitVideo ? 320 : 210,
                    maxHeight: isPortraitVideo ? 520 : 320
                )
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous))
                .overlay {
                    Group {
                        if let player = playbackController.player, playbackController.isInlinePlaybackActive {
                            InlineVideoPlayer(player: player)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            TrainingVideoThumbnailView(
                                post: post,
                                showsCompactBadges: false,
                                mediaAspectRatio: effectiveVideoAspectRatio
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous))
                }

            if playbackController.isInlinePlaybackActive, playbackController.player != nil {
                playbackControlOverlay
            }

            if playbackController.isInlinePlaybackActive, playbackController.player != nil {
                fullScreenButton
                    .padding(theme.spacing.small)
            }

            if !playbackController.isInlinePlaybackActive || playbackController.isShowingPlaybackStatusOverlay {
                videoOverlay
            }
        }
        .overlay(alignment: .bottom) {
            if playbackController.isInlinePlaybackActive, playbackController.player != nil {
                playbackProgressOverlay
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Overlay

    @ViewBuilder
    private var videoOverlay: some View {
        if playbackController.canAttemptPlayback {
            Button {
                Task {
                    await playbackController.startInlinePlayback()
                }
            } label: {
                VStack(spacing: theme.spacing.small) {
                    overlayIcon

                    if let title = playbackController.overlayTitle {
                        Text(title)
                            .font(theme.typography.bodyEmphasis)
                            .foregroundStyle(Color.white)
                    }

                    if let detail = playbackController.overlayDetail {
                        Text(detail)
                            .font(theme.typography.caption)
                            .foregroundStyle(Color.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, theme.spacing.medium)
                .padding(.vertical, theme.spacing.medium)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black.opacity(playbackController.overlayBackgroundOpacity))
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(playbackController.isPlaybackInteractionDisabled)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityHint(playbackController.overlayAccessibilityHint)
        } else {
            VStack(spacing: theme.spacing.xSmall) {
                Image(systemName: "video.slash.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(theme.spacing.medium)
                    .background(.black.opacity(0.4))
                    .clipShape(Circle())

                Text("当前暂不可播放")
                    .font(theme.typography.bodyEmphasis)
                    .foregroundStyle(Color.white)

                Text("视频地址准备好后，这里会支持页内播放。")
                    .font(theme.typography.caption)
                    .foregroundStyle(Color.white.opacity(0.86))
                    .multilineTextAlignment(.center)
            }
            .padding(theme.spacing.medium)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black.opacity(0.18))
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var playbackControlOverlay: some View {
        Button {
            playbackController.togglePlayback()
        } label: {
            ZStack {
                Color.clear

                if playbackController.isPlaybackPaused {
                    Image(systemName: playbackController.isPlaybackFinished ? "arrow.counterclockwise" : "play.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(theme.spacing.medium)
                        .background(.black.opacity(0.46))
                        .clipShape(Circle())
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(playbackController.isPlaybackFinished ? "重新播放视频" : playbackController.isPlaybackPaused ? "继续播放视频" : "暂停视频")
        .accessibilityHint(playbackController.isPlaybackFinished ? "从头重新播放视频" : playbackController.isPlaybackPaused ? "继续当前页内视频播放" : "暂停当前页内视频播放")
    }

    @ViewBuilder
    private var overlayIcon: some View {
        if playbackController.isPreparingPlayback || playbackController.isShowingPlaybackStatusOverlay {
            ProgressView()
                .tint(.white)
                .padding(theme.spacing.medium)
                .background(.black.opacity(0.42))
                .clipShape(Circle())
        } else if playbackController.playbackErrorMessage != nil {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.white)
                .padding(theme.spacing.medium)
                .background(.black.opacity(0.42))
                .clipShape(Circle())
        } else {
            Image(systemName: "play.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.white)
                .padding(theme.spacing.medium)
                .background(.black.opacity(0.42))
                .clipShape(Circle())
        }
    }

    // MARK: - Full Screen Button

    private var fullScreenButton: some View {
        Button {
            playbackController.isPresentingFullScreenPlayer = true
        } label: {
            Label("全屏播放", systemImage: "arrow.up.left.and.arrow.down.right")
                .font(theme.typography.captionEmphasis)
                .foregroundStyle(Color.white)
                .padding(.horizontal, theme.spacing.xxSmall)
                .padding(.vertical, theme.spacing.xxxSmall)
                .background(.black.opacity(0.54))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint("以全屏方式继续播放当前视频")
    }

    private var playbackProgressOverlay: some View {
        VStack(spacing: theme.spacing.xxxSmall) {
            progressBar(
                progress: playbackController.playbackProgress,
                backgroundOpacity: 0.26,
                fill: Color.white
            )

            HStack {
                Text(playbackController.currentTimeText)
                Spacer()
                Text(playbackController.durationText)
            }
            .font(theme.typography.caption)
            .monospacedDigit()
            .foregroundStyle(Color.white.opacity(0.92))
        }
        .padding(.horizontal, theme.spacing.small)
        .padding(.vertical, theme.spacing.xxSmall)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.24), .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(
            .rect(
                topLeadingRadius: 0,
                bottomLeadingRadius: theme.radius.large,
                bottomTrailingRadius: theme.radius.large,
                topTrailingRadius: 0
            )
        )
        .allowsHitTesting(false)
    }

    // MARK: - Metadata

    private var videoMetadataRow: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xSmall) {
            HStack(spacing: theme.spacing.xxSmall) {
                StatusBadge(title: post.contentType.title, tone: post.contentType.badgeTone)
                StatusBadge(title: post.analysisStatus.title, tone: post.analysisStatus.badgeTone)
            }

            HStack(spacing: theme.spacing.xxSmall) {
                metadataPill("上传于 \(Self.dateFormatter.string(from: post.uploadedAt))")

                if let durationText {
                    metadataPill("时长 \(durationText)")
                }

                if let memberProfile {
                    metadataPill(memberProfile.displayName)
                }
            }
        }
    }

    private func metadataPill(_ text: String) -> some View {
        Text(text)
            .font(theme.typography.caption)
            .foregroundStyle(theme.colors.textSecondary)
            .padding(.horizontal, theme.spacing.xxSmall)
            .padding(.vertical, theme.spacing.xxxSmall)
            .background(theme.colors.surface)
            .clipShape(Capsule())
    }

    // MARK: - Helpers

    /// Derived from the loaded video track; falls back to 16:9 until the player reports real dimensions.
    private var effectiveVideoAspectRatio: CGFloat {
        if let size = playbackController.videoNaturalSize, size.height > 0 {
            return size.width / size.height
        }
        if let size = thumbnailSize, size.height > 0 {
            return size.width / size.height
        }
        return 16.0 / 9.0
    }

    private var isPortraitVideo: Bool {
        effectiveVideoAspectRatio < 1
    }

    private var thumbnailSize: CGSize? {
        guard let thumbnailURL = post.localThumbnailURL,
              let data = try? Data(contentsOf: thumbnailURL),
              let image = UIImage(data: data) else {
            return nil
        }

        return image.size
    }

    private var postTitle: String {
        if let headline = post.displayAnalysisHeadline {
            return headline
        }

        if let drillName = post.drillName, !drillName.isEmpty {
            return drillName
        }

        return post.fileName
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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

// MARK: - Video Context Card

/// Compact chat-context card used inside the AI coach conversation scroll view.
/// The video surface sits above a slim metadata bar — the whole card scrolls with
/// the message thread so the chat area owns the full screen height.
struct VideoContextCard: View {
    @Environment(Theme.self) private var theme

    let post: TrainingVideoPost
    let memberProfile: LocalUserProfile?
    let playbackController: VideoPlaybackController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            videoSurface
            metadataBar
        }
        .background(theme.colors.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous)
                .stroke(theme.colors.border, lineWidth: theme.stroke.thin)
        }
    }

    // MARK: - Video Surface

    // Always display the card at 16:9 regardless of actual video ratio.
    // TrainingVideoThumbnailView uses scaledToFill internally, so portrait
    // content is center-cropped rather than letterboxed.
    private static let cardDisplayRatio: CGFloat = 16.0 / 9.0

    private var videoSurface: some View {
        ZStack {
            Color.black
                .frame(maxWidth: .infinity)
                .aspectRatio(Self.cardDisplayRatio, contentMode: .fit)
                .overlay {
                    Group {
                        if let player = playbackController.player, playbackController.isInlinePlaybackActive {
                            InlineVideoPlayer(player: player)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            TrainingVideoThumbnailView(
                                post: post,
                                showsCompactBadges: false,
                                mediaAspectRatio: Self.cardDisplayRatio
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }

            if playbackController.isInlinePlaybackActive, playbackController.player != nil {
                cardPlaybackControlOverlay
            }

            if !playbackController.isInlinePlaybackActive || playbackController.isShowingPlaybackStatusOverlay {
                cardVideoOverlay
            }
        }
        .overlay(alignment: .bottom) {
            if playbackController.isInlinePlaybackActive, playbackController.player != nil {
                cardPlaybackProgressOverlay
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .clipShape(
            .rect(
                topLeadingRadius: theme.radius.large,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: theme.radius.large
            )
        )
        .accessibilityElement(children: .contain)
    }

    // MARK: - Overlays

    @ViewBuilder
    private var cardVideoOverlay: some View {
        if playbackController.canAttemptPlayback {
            Button {
                Task { await playbackController.startInlinePlayback() }
            } label: {
                VStack(spacing: theme.spacing.xSmall) {
                    cardOverlayIcon

                    if let title = playbackController.overlayTitle {
                        Text(title)
                            .font(theme.typography.bodyEmphasis)
                            .foregroundStyle(Color.white)
                    }

                    if let detail = playbackController.overlayDetail {
                        Text(detail)
                            .font(theme.typography.caption)
                            .foregroundStyle(Color.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, theme.spacing.medium)
                .padding(.vertical, theme.spacing.medium)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black.opacity(playbackController.overlayBackgroundOpacity))
            }
            .buttonStyle(.plain)
            .disabled(playbackController.isPlaybackInteractionDisabled)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityHint(playbackController.overlayAccessibilityHint)
        } else {
            VStack(spacing: theme.spacing.xSmall) {
                Image(systemName: "video.slash.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(theme.spacing.small)
                    .background(.black.opacity(0.4))
                    .clipShape(Circle())

                Text("当前暂不可播放")
                    .font(theme.typography.caption)
                    .foregroundStyle(Color.white)
            }
            .padding(theme.spacing.medium)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black.opacity(0.18))
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var cardPlaybackControlOverlay: some View {
        Button {
            playbackController.togglePlayback()
        } label: {
            ZStack {
                Color.clear

                if playbackController.isPlaybackPaused {
                    Image(systemName: playbackController.isPlaybackFinished ? "arrow.counterclockwise" : "play.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(theme.spacing.small)
                        .background(.black.opacity(0.46))
                        .clipShape(Circle())
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(playbackController.isPlaybackFinished ? "重新播放视频" : playbackController.isPlaybackPaused ? "继续播放视频" : "暂停视频")
        .accessibilityHint(playbackController.isPlaybackFinished ? "从头重新播放视频" : playbackController.isPlaybackPaused ? "继续当前页内视频播放" : "暂停当前页内视频播放")
    }

    @ViewBuilder
    private var cardOverlayIcon: some View {
        if playbackController.isPreparingPlayback || playbackController.isShowingPlaybackStatusOverlay {
            ProgressView()
                .tint(.white)
                .padding(theme.spacing.small)
                .background(.black.opacity(0.42))
                .clipShape(Circle())
        } else if playbackController.playbackErrorMessage != nil {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.white)
                .padding(theme.spacing.small)
                .background(.black.opacity(0.42))
                .clipShape(Circle())
        } else {
            Image(systemName: "play.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.white)
                .padding(theme.spacing.small)
                .background(.black.opacity(0.42))
                .clipShape(Circle())
        }
    }

    private var cardPlaybackProgressOverlay: some View {
        VStack(spacing: theme.spacing.xxxSmall) {
            progressBar(
                progress: playbackController.playbackProgress,
                backgroundOpacity: 0.22,
                fill: Color.white
            )

            HStack {
                Text(playbackController.currentTimeText)
                Spacer()
                Text(playbackController.durationText)
            }
            .font(theme.typography.caption)
            .monospacedDigit()
            .foregroundStyle(Color.white.opacity(0.9))
        }
        .padding(.horizontal, theme.spacing.small)
        .padding(.vertical, theme.spacing.xxSmall)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.2), .black.opacity(0.62)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .allowsHitTesting(false)
    }

    // MARK: - Metadata Bar

    private var metadataBar: some View {
        HStack(alignment: .center, spacing: theme.spacing.small) {
            VStack(alignment: .leading, spacing: theme.spacing.xxxSmall) {
                HStack(spacing: theme.spacing.xxSmall) {
                    StatusBadge(title: post.contentType.title, tone: post.contentType.badgeTone)
                    StatusBadge(title: post.analysisStatus.title, tone: post.analysisStatus.badgeTone)
                }

                HStack(spacing: theme.spacing.xxSmall) {
                    cardMetadataPill("上传于 \(Self.cardDateFormatter.string(from: post.uploadedAt))")

                    if let durationText {
                        cardMetadataPill("时长 \(durationText)")
                    }

                    if let memberProfile {
                        cardMetadataPill(memberProfile.displayName)
                    }
                }
            }

            Spacer()

            Button {
                playbackController.isPresentingFullScreenPlayer = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.colors.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(theme.colors.fill)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("全屏播放")
            .accessibilityHint("以全屏方式播放当前视频")
        }
        .padding(theme.spacing.small)
    }

    private func cardMetadataPill(_ text: String) -> some View {
        Text(text)
            .font(theme.typography.caption)
            .foregroundStyle(theme.colors.textSecondary)
            .padding(.horizontal, theme.spacing.xxSmall)
            .padding(.vertical, theme.spacing.xxxSmall)
            .background(theme.colors.surface)
            .clipShape(Capsule())
    }

    // MARK: - Helpers

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

    private static let cardDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

private func progressBar(progress: Double, backgroundOpacity: Double, fill: Color) -> some View {
    GeometryReader { proxy in
        let clamped = min(max(progress, 0), 1)

        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(backgroundOpacity))

            Capsule()
                .fill(fill)
                .frame(width: max(proxy.size.width * clamped, 0))
        }
    }
    .frame(height: 4)
}
