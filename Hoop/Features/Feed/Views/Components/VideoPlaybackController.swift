import AVKit
import Observation
import SwiftUI

@MainActor
@Observable
final class VideoPlaybackController {
    // MARK: - Public State

    private(set) var player: AVPlayer?
    private(set) var isInlinePlaybackActive = false
    var isPresentingFullScreenPlayer = false
    private(set) var isPreparingPlayback = false
    private(set) var isPreloadingPlayback = false
    private(set) var isPlaybackPaused = false
    private(set) var isPlaybackFinished = false
    private(set) var playbackStatusMessage: String?
    private(set) var playbackErrorMessage: String?
    private(set) var currentTimeSeconds: Double = 0
    private(set) var durationSeconds: Double = 0
    /// Natural pixel dimensions of the loaded video track; nil until readyToPlay.
    private(set) var videoNaturalSize: CGSize?

    // MARK: - Internal State

    private var resolvedPlaybackURL: URL?
    private var hasRetriedPlaybackAfterFailure = false
    private var playerStatusObserver: NSKeyValueObservation?
    private var playerTimeControlObserver: NSKeyValueObservation?
    private var playerDidPlayToEndTimeObserver: NSObjectProtocol?
    private var playerPeriodicTimeObserver: Any?

    // MARK: - Dependencies

    private let objectKey: String
    private let remoteVideoURL: URL?

    // MARK: - Computed

    var canAttemptPlayback: Bool {
        !objectKey.isEmpty || remoteVideoURL != nil
    }

    var isShowingPlaybackStatusOverlay: Bool {
        isInlinePlaybackActive && playbackStatusMessage != nil
    }

    var isPlaybackInteractionDisabled: Bool {
        isPreparingPlayback || isShowingPlaybackStatusOverlay
    }

    var overlayBackgroundOpacity: Double {
        isPreparingPlayback || isShowingPlaybackStatusOverlay ? 0.38 : 0.24
    }

    var overlayTitle: String? {
        if let playbackStatusMessage {
            return playbackStatusMessage
        }

        if playbackErrorMessage != nil {
            return "播放失败，点击重试"
        }

        if isPreloadingPlayback {
            return "视频已准备，点击播放"
        }

        return "播放视频"
    }

    var overlayDetail: String? {
        if let playbackErrorMessage {
            return playbackErrorMessage
        }

        if isPreloadingPlayback {
            return "已提前完成连接准备，首击后会更快开始播放。"
        }

        if isPreparingPlayback || isShowingPlaybackStatusOverlay {
            return "第一次点击已经生效，请稍等片刻。"
        }

        return nil
    }

    var overlayAccessibilityHint: String {
        if playbackErrorMessage != nil {
            return "重新尝试在当前页面内播放这条视频"
        }

        return "在当前页面内播放这条视频"
    }

    var playbackProgress: Double {
        guard durationSeconds.isFinite, durationSeconds > 0 else { return 0 }
        return min(max(currentTimeSeconds / durationSeconds, 0), 1)
    }

    var currentTimeText: String {
        Self.formatPlaybackTime(currentTimeSeconds)
    }

    var durationText: String {
        Self.formatPlaybackTime(durationSeconds)
    }

    // MARK: - Init / Deinit

    init(objectKey: String, remoteVideoURL: URL?) {
        self.objectKey = objectKey
        self.remoteVideoURL = remoteVideoURL
    }

    // NSKeyValueObservation auto-invalidates on deallocation, no deinit needed.

    // MARK: - Public Actions

    func preloadIfNeeded() async {
        guard canAttemptPlayback,
              resolvedPlaybackURL == nil,
              !isPreloadingPlayback,
              !isPreparingPlayback else { return }

        isPreloadingPlayback = true
        defer { isPreloadingPlayback = false }

        do {
            let url = try await resolvePlaybackURL(forceRefresh: false)
            resolvedPlaybackURL = url
            await resolveVideoNaturalSize(from: url)
        } catch {
            // Keep silent so page entry doesn't feel broken before the user taps play.
        }
    }

    func startInlinePlayback() async {
        guard !isPreparingPlayback else { return }

        isPreparingPlayback = true
        isPlaybackPaused = false
        isPlaybackFinished = false
        playbackStatusMessage = "正在连接视频..."
        playbackErrorMessage = nil
        defer { isPreparingPlayback = false }

        do {
            let playbackURL = try await playbackURLForCurrentAttempt()
            configurePlayer(with: playbackURL)
            hasRetriedPlaybackAfterFailure = false
            isInlinePlaybackActive = true
            player?.play()
        } catch {
            isInlinePlaybackActive = false
            playbackStatusMessage = nil
            playbackErrorMessage = Self.safePlaybackMessage(for: error)
        }
    }

    func togglePlayback() {
        guard isInlinePlaybackActive,
              !isPreparingPlayback,
              !isShowingPlaybackStatusOverlay else { return }

        if isPlaybackFinished {
            replayFromStart()
        } else if isPlaybackPaused {
            resumePlayback()
        } else {
            pausePlayback()
        }
    }

    func tearDown(keepPlayerForFullScreen: Bool) {
        removePlayerObservers()
        guard !keepPlayerForFullScreen else { return }
        player?.pause()
        isPlaybackPaused = false
    }

    // MARK: - Private

    private func playbackURLForCurrentAttempt() async throws -> URL {
        if let resolvedPlaybackURL {
            return resolvedPlaybackURL
        }

        let url = try await resolvePlaybackURL(forceRefresh: false)
        resolvedPlaybackURL = url
        return url
    }

    private func resolvePlaybackURL(forceRefresh: Bool) async throws -> URL {
        if !forceRefresh, let resolvedPlaybackURL {
            return resolvedPlaybackURL
        }

        if !objectKey.isEmpty {
            do {
                let service = try OSSUploadService()
                return try await service.playbackURL(for: objectKey)
            } catch {
                if let remoteVideoURL {
                    return remoteVideoURL
                }
                throw error
            }
        }

        if let remoteVideoURL {
            return remoteVideoURL
        }

        throw OSSPlaybackURLError.invalidPresignedURL
    }

    private func configurePlayer(with url: URL) {
        removePlayerObservers()

        let item = AVPlayerItem(url: url)
        currentTimeSeconds = 0
        durationSeconds = 0

        if let player {
            player.replaceCurrentItem(with: item)
        } else {
            player = AVPlayer(playerItem: item)
        }

        resolvedPlaybackURL = url
        attachPlayerObservers()
        Task {
            await resolveVideoNaturalSize(from: url)
        }
    }

    private func attachPlayerObservers() {
        guard let player else { return }

        playerStatusObserver = player.currentItem?.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                self?.handlePlayerItemStatus(item.status, error: item.error)
            }
        }

        playerTimeControlObserver = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in
                self?.handlePlayerTimeControlStatus(player.timeControlStatus)
            }
        }

        playerPeriodicTimeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.handlePlaybackTimeDidChange(time)
            }
        }

        playerDidPlayToEndTimeObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handlePlaybackDidFinish()
            }
        }
    }

    private func removePlayerObservers() {
        playerStatusObserver?.invalidate()
        playerStatusObserver = nil
        playerTimeControlObserver?.invalidate()
        playerTimeControlObserver = nil
        if let playerPeriodicTimeObserver, let player {
            player.removeTimeObserver(playerPeriodicTimeObserver)
            self.playerPeriodicTimeObserver = nil
        }
        if let observer = playerDidPlayToEndTimeObserver {
            NotificationCenter.default.removeObserver(observer)
            playerDidPlayToEndTimeObserver = nil
        }
    }

    private func handlePlayerItemStatus(_ status: AVPlayerItem.Status, error: Error?) {
        switch status {
        case .unknown:
            if isInlinePlaybackActive {
                playbackStatusMessage = "正在加载视频..."
            }
        case .readyToPlay:
            if let item = player?.currentItem {
                updateDuration(from: item)
                Task {
                    await resolveVideoNaturalSize(from: item)
                }
            }
            if isInlinePlaybackActive, player?.timeControlStatus != .playing {
                playbackStatusMessage = "视频已就绪，正在开始播放..."
            }
        case .failed:
            Task {
                await recoverOrSurfacePlaybackFailure(error)
            }
        @unknown default:
            break
        }
    }

    /// Derives visual dimensions from the video track's natural size + preferred transform.
    /// `presentationSize` can return raw pixel dimensions without applying the rotation
    /// embedded in the video metadata, causing portrait videos to appear tiny inside a
    /// landscape-aspect frame. Using the track transform gives the correct visual size.
    private func resolveVideoNaturalSize(from url: URL) async {
        let asset = AVURLAsset(url: url)

        do {
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            if let videoTrack = videoTracks.first {
                let naturalSize = try await videoTrack.load(.naturalSize)
                let preferredTransform = try await videoTrack.load(.preferredTransform)
                let transformed = naturalSize.applying(preferredTransform)
                let visual = CGSize(width: abs(transformed.width), height: abs(transformed.height))

                if resolvedPlaybackURL == url, visual.width > 0, visual.height > 0 {
                    videoNaturalSize = visual
                    return
                }
            }
        } catch {
            // Fall back to player-derived metadata when direct asset loading is unavailable.
        }

        if resolvedPlaybackURL == url, let item = player?.currentItem {
            await resolveVideoNaturalSize(from: item)
        }
    }

    private func resolveVideoNaturalSize(from item: AVPlayerItem) async {
        do {
            let videoTracks = try await item.asset.loadTracks(withMediaType: .video)
            if let videoTrack = videoTracks.first {
                let naturalSize = try await videoTrack.load(.naturalSize)
                let preferredTransform = try await videoTrack.load(.preferredTransform)
                let transformed = naturalSize.applying(preferredTransform)
                let visual = CGSize(width: abs(transformed.width), height: abs(transformed.height))

                if visual.width > 0, visual.height > 0 {
                    videoNaturalSize = visual
                    return
                }
            }
        } catch {
            // Fall back to presentation size when the asset track is unavailable.
        }

        if item.presentationSize != .zero {
            let size = item.presentationSize
            videoNaturalSize = size
        }
    }

    private func handlePlayerTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
        guard isInlinePlaybackActive else { return }

        switch status {
        case .paused:
            isPlaybackPaused = true
        case .waitingToPlayAtSpecifiedRate:
            isPlaybackPaused = false
            playbackStatusMessage = "正在缓冲视频..."
        case .playing:
            isPlaybackPaused = false
            isPlaybackFinished = false
            playbackStatusMessage = nil
            playbackErrorMessage = nil
        @unknown default:
            break
        }
    }

    private func handlePlaybackTimeDidChange(_ time: CMTime) {
        guard isInlinePlaybackActive else { return }

        let seconds = time.seconds
        if seconds.isFinite, seconds >= 0 {
            currentTimeSeconds = seconds
        }

        if let item = player?.currentItem {
            updateDuration(from: item)
        }
    }

    private func recoverOrSurfacePlaybackFailure(_ error: Error?) async {
        if !hasRetriedPlaybackAfterFailure {
            hasRetriedPlaybackAfterFailure = true
            playbackStatusMessage = "连接波动，正在重试..."
            resolvedPlaybackURL = nil

            do {
                let playbackURL = try await resolvePlaybackURL(forceRefresh: true)
                configurePlayer(with: playbackURL)
                isInlinePlaybackActive = true
                player?.play()
                return
            } catch {
                finishPlaybackFailure(error)
                return
            }
        }

        finishPlaybackFailure(error)
    }

    private func finishPlaybackFailure(_ error: Error?) {
        player?.pause()
        isInlinePlaybackActive = false
        isPlaybackPaused = false
        playbackStatusMessage = nil
        playbackErrorMessage = Self.safePlaybackMessage(for: error)
    }

    private func handlePlaybackDidFinish() {
        guard isInlinePlaybackActive else { return }
        currentTimeSeconds = durationSeconds
        isPlaybackFinished = true
        isPlaybackPaused = true
    }

    private func replayFromStart() {
        isPlaybackFinished = false
        isPlaybackPaused = false
        currentTimeSeconds = 0
        player?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.player?.play()
            }
        }
    }

    private func pausePlayback() {
        player?.pause()
        isPlaybackPaused = true
    }

    private func resumePlayback() {
        isPlaybackPaused = false
        player?.play()
    }

    private func updateDuration(from item: AVPlayerItem) {
        let seconds = item.duration.seconds
        if seconds.isFinite, seconds > 0 {
            durationSeconds = seconds
        }
    }

    private static func formatPlaybackTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else {
            return "00:00"
        }

        let totalSeconds = Int(seconds.rounded(.down))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let remainingSeconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }

        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private static func safePlaybackMessage(for error: Error?) -> String {
        guard let error else {
            return "暂时无法播放这条视频，请稍后重试。"
        }

        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            return description
        }

        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? "暂时无法播放这条视频，请稍后重试。" : message
    }
}
