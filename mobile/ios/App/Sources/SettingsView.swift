import SwiftUI

struct SettingsView: View {
    @Binding var selectedProfile: VoiceProfile

    var body: some View {
        Form {
            Section("Workflow preset") {
                Picker("Profile", selection: $selectedProfile) {
                    ForEach(VoiceProfile.defaults) { profile in
                        Text(profile.title).tag(profile)
                    }
                }
            }

            Section("Current direction") {
                Text("Keep the UI native.")
                Text("Share prompt/profile/runtime logic where it reduces drift.")
                Text("Treat the keyboard extension as a product surface, not a debug shell.")
            }
        }
        .navigationTitle("Settings")
    }
}
