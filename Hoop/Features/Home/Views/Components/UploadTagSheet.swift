import AVKit
import SwiftUI
import UniformTypeIdentifiers
import UIKit

enum VideoSourceAction: String, Identifiable {
    case camera
    case library

    var id: String { rawValue }

    var title: String {
        switch self {
        case .camera:
            return "拍摄视频"
        case .library:
            return "从相册选择"
        }
    }

    var symbolName: String {
        switch self {
        case .camera:
            return "video.fill"
        case .library:
            return "photo.on.rectangle.angled"
        }
    }

    var pickerSourceType: UIImagePickerController.SourceType {
        switch self {
        case .camera:
            return .camera
        case .library:
            return .photoLibrary
        }
    }
}

struct PendingVideoDraft: Identifiable {
    let fileURL: URL
    let source: VideoSourceAction

    var id: String { fileURL.absoluteString }
}

struct VideoComposerView: View {
    @Environment(Theme.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var selectedContentType: TrainingVideoContentType = .training
    @State private var drillName = ""

    let videoURL: URL
    let source: VideoSourceAction
    let onPublish: (TrainingVideoContentType, String?) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.large) {
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        HStack(spacing: theme.spacing.xSmall) {
                            Label(source.title, systemImage: source.symbolName)
                                .font(theme.typography.captionEmphasis)
                                .foregroundStyle(theme.colors.brand)
                                .padding(.horizontal, theme.spacing.small)
                                .padding(.vertical, theme.spacing.xxxSmall)
                                .background(theme.colors.brand.opacity(0.12))
                                .clipShape(Capsule())

                            Spacer()
                        }

                        Text("发一条视频动态")
                            .font(theme.typography.title2)
                            .foregroundStyle(theme.colors.textPrimary)

                        Text("确认视频内容后发布到动态，上传完成后会立即出现在时间流里。")
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colors.textSecondary)
                    }

                    VideoComposerPreview(videoURL: videoURL)

                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        Text("视频类型")
                            .font(theme.typography.captionEmphasis)
                            .foregroundStyle(theme.colors.textSecondary)

                        HStack(spacing: theme.spacing.small) {
                            ForEach(TrainingVideoContentType.allCases, id: \.rawValue) { type in
                                Button {
                                    selectedContentType = type
                                } label: {
                                    Text(type.title)
                                        .font(theme.typography.bodyEmphasis)
                                        .foregroundStyle(
                                            selectedContentType == type
                                            ? theme.colors.textOnBrand
                                            : theme.colors.textSecondary
                                        )
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, theme.spacing.small)
                                        .background(
                                            selectedContentType == type
                                            ? theme.colors.brand
                                            : theme.colors.surface
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous))
                                        .overlay {
                                            if selectedContentType != type {
                                                RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous)
                                                    .stroke(theme.colors.border, lineWidth: theme.stroke.thin)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: theme.spacing.xSmall) {
                        Text("训练名称（可选）")
                            .font(theme.typography.captionEmphasis)
                            .foregroundStyle(theme.colors.textSecondary)

                        TextField("如：三分线投篮训练", text: $drillName)
                            .textInputAutocapitalization(.never)
                            .font(theme.typography.body)
                            .padding(theme.spacing.small)
                            .background(theme.colors.surfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous)
                                    .stroke(theme.colors.border, lineWidth: theme.stroke.thin)
                            }
                    }
                }
                .padding(theme.spacing.pageMargin)
                .padding(.bottom, theme.spacing.large)
            }
            .navigationTitle("发布视频")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("发布") {
                        let name = drillName.trimmingCharacters(in: .whitespacesAndNewlines)
                        onPublish(selectedContentType, name.isEmpty ? nil : name)
                    }
                    .font(theme.typography.bodyEmphasis)
                }
            }
            .hoopScreenBackground(theme)
        }
    }
}

private struct VideoComposerPreview: View {
    @Environment(Theme.self) private var theme
    @State private var player: AVPlayer

    private static let previewAspectRatio: CGFloat = 16.0 / 9.0

    init(videoURL: URL) {
        _player = State(initialValue: AVPlayer(url: videoURL))
    }

    var body: some View {
        VideoPlayer(player: player)
            .aspectRatio(Self.previewAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                Label("视频预览", systemImage: "play.circle.fill")
                    .font(theme.typography.captionEmphasis)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, theme.spacing.small)
                    .padding(.vertical, theme.spacing.xxxSmall)
                    .background(Color.black.opacity(0.48))
                    .clipShape(Capsule())
                    .padding(theme.spacing.small)
            }
            .onAppear {
                player.play()
            }
            .onDisappear {
                player.pause()
            }
    }
}

struct SystemVideoPickerView: UIViewControllerRepresentable {
    let source: VideoSourceAction
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.mediaTypes = [UTType.movie.identifier]
        picker.videoQuality = .typeHigh
        picker.sourceType = source.pickerSourceType

        if source == .camera {
            picker.cameraCaptureMode = .video
            picker.videoMaximumDuration = 180
        }

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onPick: (URL) -> Void
        private let onCancel: () -> Void

        init(
            onPick: @escaping (URL) -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let mediaURL = info[.mediaURL] as? URL else {
                onCancel()
                return
            }

            do {
                let copiedURL = try Self.copyVideoToTemporaryDirectory(from: mediaURL)
                onPick(copiedURL)
            } catch {
                onCancel()
            }
        }

        private static func copyVideoToTemporaryDirectory(from sourceURL: URL) throws -> URL {
            let pathExtension = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
            let copyURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(pathExtension)

            if FileManager.default.fileExists(atPath: copyURL.path) {
                try FileManager.default.removeItem(at: copyURL)
            }

            try FileManager.default.copyItem(at: sourceURL, to: copyURL)
            return copyURL
        }
    }
}
