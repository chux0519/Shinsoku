import SwiftUI

struct RootView: View {
    @EnvironmentObject private var workspace: IOSVoiceWorkspace

    var body: some View {
        NavigationStack {
            HomeView()
                .toolbar {
                    NavigationLink("Settings") {
                        SettingsView()
                    }
                }
        }
    }
}
