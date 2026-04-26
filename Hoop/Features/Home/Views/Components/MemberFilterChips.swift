import SwiftUI

struct MemberFilterChips: View {
    @Environment(Theme.self) private var theme

    let profiles: [LocalUserProfile]
    @Binding var selectedID: String

    static let allMembersID = "all-members"

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacing.xSmall) {
                chip(id: Self.allMembersID, label: "全部")

                ForEach(profiles, id: \.id) { profile in
                    chip(id: profile.id, label: "\(profile.avatarEmoji) \(profile.displayName)")
                }
            }
            .padding(.horizontal, theme.spacing.pageMargin)
        }
    }

    private func chip(id: String, label: String) -> some View {
        Button {
            selectedID = id
        } label: {
            Text(label)
                .font(theme.typography.captionEmphasis)
                .foregroundStyle(selectedID == id ? Color.white : theme.colors.textSecondary)
                .padding(.horizontal, theme.spacing.small)
                .padding(.vertical, theme.spacing.xxSmall)
                .background(selectedID == id ? theme.colors.brand : theme.colors.surface)
                .clipShape(Capsule())
                .overlay {
                    if selectedID != id {
                        Capsule()
                            .stroke(theme.colors.border, lineWidth: theme.stroke.thin)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
