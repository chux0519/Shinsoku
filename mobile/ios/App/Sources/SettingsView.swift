import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var workspace: IOSVoiceWorkspace

    var body: some View {
        Form {
            Section("Runtime status") {
                LabeledContent("Selected profile", value: workspace.selectedProfile.title)
                LabeledContent("Saved drafts", value: "\(workspace.storageDiagnostics.draftCount)")
                LabeledContent("Shared app group", value: workspace.storageDiagnostics.appGroupID)
                LabeledContent("Shared storage") {
                    Text(workspace.storageDiagnostics.isUsingSharedDefaults ? "Ready" : "Fallback")
                        .foregroundStyle(workspace.storageDiagnostics.isUsingSharedDefaults ? Color.secondary : Color.red)
                }
            }

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
                Text("Drafts saved in the app are inserted by the keyboard extension with profile-aware suffix behavior.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Clear saved drafts", role: .destructive) {
                    workspace.clearDrafts()
                }
            }

            Section("Setup reminders") {
                Text("Grant microphone and speech recognition access in the app first.")
                Text("Enable Shinsoku Keyboard in Settings > General > Keyboard > Keyboards.")
                Text("Allow Full Access if you want the keyboard extension to open the app and stay in sync with shared drafts.")
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            workspace.refresh()
        }
    }
}
