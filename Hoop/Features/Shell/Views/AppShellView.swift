import SwiftUI

struct AppShellView: View {
    @State private var selectedTab: AppTab = .feed

    @Bindable var viewModel: AuthViewModel
    let deviceUser: AuthenticatedUser

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label(AppTab.feed.title, systemImage: AppTab.feed.systemImage) }
            .tag(AppTab.feed)

            NavigationStack {
                ProfileView(viewModel: viewModel, deviceUser: deviceUser)
            }
            .tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.systemImage) }
            .tag(AppTab.profile)
        }
    }
}
