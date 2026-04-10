import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var workspace: IOSVoiceWorkspace
    @EnvironmentObject private var transcriber: SpeechTranscriber

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                runtimeCard
                workflowCard
                keyboardCard
                linksCard
                setupCard
                draftsCard
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Settings")
        .onAppear {
            workspace.refresh()
            transcriber.refreshAuthorizationState()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Settings")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
            Text("Keep the app, shared drafts, and keyboard extension aligned.")
                .foregroundStyle(.secondary)
        }
    }

    private var runtimeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Runtime status")
                .font(.headline)
            LabeledContent("Selected profile", value: workspace.selectedProfile.title)
            LabeledContent("Saved drafts", value: "\(workspace.storageDiagnostics.draftCount)")
            LabeledContent("Shared app group", value: workspace.storageDiagnostics.appGroupID)
            LabeledContent("Shared storage") {
                Text(workspace.storageDiagnostics.isUsingSharedDefaults ? "Ready" : "Fallback")
                    .foregroundStyle(workspace.storageDiagnostics.isUsingSharedDefaults ? Color.secondary : Color.red)
            }
        }
        .shinsokuSettingsCard()
    }

    private var workflowCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workflow preset")
                .font(.headline)
            Picker("Profile", selection: Binding(
                get: { workspace.selectedProfile },
                set: { workspace.selectProfile($0) }
            )) {
                ForEach(VoiceProfile.defaults) { profile in
                    Text(profile.title).tag(profile)
                }
            }
            .pickerStyle(.menu)
            Text(workspace.selectedProfile.mode.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .shinsokuSettingsCard()
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Setup reminders")
                .font(.headline)
            reminderRow(number: 1, text: "Grant microphone and speech recognition access in the app first.")
            reminderRow(number: 2, text: "Enable Shinsoku Keyboard in Settings > General > Keyboard > Keyboards.")
            reminderRow(number: 3, text: "Allow Full Access if you want the keyboard extension to open the app and stay in sync with shared drafts.")
        }
        .shinsokuSettingsCard()
    }

    private var keyboardCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard handoff")
                .font(.headline)
            Text("Shinsoku on iOS works as a two-part flow: dictate in the app, then insert from the keyboard extension.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            LabeledContent("Speech access") {
                Text(transcriber.authorizationState == .ready ? "Ready" : "Needs attention")
                    .foregroundStyle(transcriber.authorizationState == .ready ? Color.secondary : Color.orange)
            }

            NavigationLink("Open setup guide") {
                SetupGuideView()
            }
            .buttonStyle(.bordered)
        }
        .shinsokuSettingsCard()
    }

    private var draftsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shared drafts")
                .font(.headline)
            Text("Drafts saved in the app are inserted by the keyboard extension with profile-aware suffix behavior.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Clear saved drafts", role: .destructive) {
                workspace.clearDrafts()
            }
            .buttonStyle(.bordered)
        }
        .shinsokuSettingsCard()
    }

    private var linksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shortcuts")
                .font(.headline)
            HStack(spacing: 12) {
                NavigationLink("Setup guide") {
                    SetupGuideView()
                }
                .buttonStyle(.bordered)

                Button("Open iOS Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.bordered)
            }
        }
        .shinsokuSettingsCard()
    }

    private func reminderRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.footnote.weight(.semibold))
                .frame(width: 22, height: 22)
                .background(Color(.secondarySystemBackground), in: Circle())
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private extension View {
    func shinsokuSettingsCard() -> some View {
        padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
