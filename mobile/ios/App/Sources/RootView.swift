import SwiftUI

struct RootView: View {
    private enum Tab: Hashable {
        case home
        case drafts
        case settings
    }

    @EnvironmentObject private var workspace: IOSVoiceWorkspace
    @State private var selectedTab: Tab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "waveform")
            }
            .tag(Tab.home)

            NavigationStack {
                DraftsView()
            }
            .tabItem {
                Label("Drafts", systemImage: "doc.text")
            }
            .tag(Tab.drafts)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(Tab.settings)
        }
        .onOpenURL { url in
            guard url.scheme == "shinsoku" else { return }
            switch url.host {
            case "drafts":
                selectedTab = .drafts
            case "settings":
                selectedTab = .settings
            default:
                selectedTab = .home
            }
            workspace.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .shinsokuOpenDrafts)) { _ in
            selectedTab = .drafts
            workspace.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .shinsokuOpenSettings)) { _ in
            selectedTab = .settings
            workspace.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .shinsokuOpenHome)) { _ in
            selectedTab = .home
            workspace.refresh()
        }
    }
}
