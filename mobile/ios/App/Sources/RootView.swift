import SwiftUI

struct RootView: View {
    @Binding var selectedProfile: VoiceProfile

    var body: some View {
        NavigationStack {
            HomeView(selectedProfile: $selectedProfile)
                .toolbar {
                    NavigationLink("Settings") {
                        SettingsView(selectedProfile: $selectedProfile)
                    }
                }
        }
    }
}
