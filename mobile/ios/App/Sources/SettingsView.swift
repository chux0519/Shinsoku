import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var workspace: IOSVoiceWorkspace

    var body: some View {
        Form {
            Section("Workflow preset") {
                Picker("Profile", selection: Binding(
                    get: { workspace.selectedProfile },
                    set: { workspace.selectProfile($0) }
                )) {
                    ForEach(VoiceProfile.defaults) { profile in
                        Text(profile.title).tag(profile)
                    }
                }
            }

            Section("Shared drafts") {
                Button("Clear saved drafts", role: .destructive) {
                    workspace.clearDrafts()
                }
            }

            Section("Current direction") {
                Text("Use the iOS app for recording and live transcript review.")
                Text("Use the keyboard extension to insert recent drafts into the current editor.")
                Text("Keep prompt/profile/runtime logic aligned with Android and desktop.")
            }
        }
        .navigationTitle("Settings")
    }
}
