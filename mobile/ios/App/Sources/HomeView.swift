import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var workspace: IOSVoiceWorkspace
    @EnvironmentObject private var transcriber: SpeechTranscriber

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                permissionCard
                dictationCard
                keyboardCard
                draftsCard
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Shinsoku")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if transcriber.authorizationState == .unknown {
                await transcriber.requestPermissions()
            }
            workspace.refresh()
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Shinsoku")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
            Text("Speak in the app, then insert from the keyboard.")
                .foregroundStyle(.secondary)
            Text("The app owns dictation and draft review. The keyboard stays focused on quick insertion into the current field.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Speech readiness")
                .font(.headline)
            Text(transcriber.authorizationState.description)
                .foregroundStyle(.secondary)
            Button("Request permissions") {
                Task {
                    await transcriber.requestPermissions()
                }
            }
            .buttonStyle(.bordered)

            Button("Open app settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .buttonStyle(.bordered)
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var dictationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current profile")
                        .font(.headline)
                    Text(workspace.selectedProfile.title)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Profile", selection: Binding(
                    get: { workspace.selectedProfile },
                    set: { workspace.selectProfile($0) }
                )) {
                    ForEach(VoiceProfile.defaults) { profile in
                        Text(profile.title).tag(profile)
                    }
                }
                .pickerStyle(.menu)
            }

            Text(transcriber.transcript.isEmpty ? "Transcript will appear here." : transcriber.transcript)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                .padding(16)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            if let errorMessage = transcriber.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Text("Tip: use Review when you want to keep the text in drafts first, then insert it from the keyboard after a quick pass.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button(transcriber.isRecording ? "Stop" : "Start dictation") {
                    if transcriber.isRecording {
                        transcriber.stop()
                    } else {
                        transcriber.start(localeIdentifier: workspace.selectedProfile.languageTag)
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Save draft") {
                    workspace.saveDraft(transcriber.transcript)
                }
                .buttonStyle(.bordered)
                .disabled(transcriber.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Clear") {
                    transcriber.stop(resetTranscript: true)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var draftsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent drafts")
                    .font(.headline)
                Spacer()
                NavigationLink("Manage") {
                    DraftsView()
                }
            }
            if workspace.drafts.isEmpty {
                Text("No saved drafts yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(workspace.drafts.prefix(3)) { draft in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(draft.text)
                            .lineLimit(3)
                        Text("\(profileTitle(for: draft.profileID)) · \(DisplayFormatting.relativeTimestamp(for: draft.updatedAt))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    if draft.id != workspace.drafts.prefix(3).last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var keyboardCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Keyboard extension")
                    .font(.headline)
                Spacer()
                Button("Open Drafts") {
                    NotificationCenter.default.post(name: .shinsokuOpenDrafts, object: nil)
                }
                .buttonStyle(.bordered)
            }
            Text("Insert from the keyboard with profile-aware suffix behavior. Dictation appends a space, chat appends a newline, and review inserts the text as-is.")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                setupStep(number: 1, text: "Enable Shinsoku Keyboard in iOS Settings > General > Keyboard > Keyboards.")
                setupStep(number: 2, text: "Return here, dictate a phrase, and save it as a draft.")
                setupStep(number: 3, text: "Switch to Shinsoku Keyboard in any text field, then insert the saved draft.")
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func profileTitle(for id: String) -> String {
        VoiceProfile.defaults.first(where: { $0.id == id })?.title ?? id
    }

    private func setupStep(number: Int, text: String) -> some View {
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

extension Notification.Name {
    static let shinsokuOpenDrafts = Notification.Name("shinsokuOpenDrafts")
}
