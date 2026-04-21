import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var workspace: IOSVoiceWorkspace
    @EnvironmentObject private var transcriber: SpeechTranscriber

    private var hasTranscript: Bool {
        !transcriber.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero
                dictationCard
                statusCard
                recentDraftsCard
                keyboardHandoffCard
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Shinsoku")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    NotificationCenter.default.post(name: .shinsokuOpenSettings, object: nil)
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .task {
            transcriber.refreshAuthorizationState()
            if transcriber.authorizationState == .unknown {
                await transcriber.requestPermissions()
            }
            workspace.refresh()
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Shinsoku")
                .font(.system(size: 36, weight: .semibold, design: .rounded))
            Text("Speak here. Insert from the keyboard.")
                .font(.title3.weight(.semibold))
            Text("iOS keeps dictation in the app and handoff in the keyboard extension. This mirrors Android's flow without fighting iOS input-method limits.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                statusChip(title: workspace.selectedProfile.title, systemImage: "slider.horizontal.3")
                statusChip(title: runtimeProviderLabel, systemImage: "antenna.radiowaves.left.and.right")
                statusChip(title: "\(workspace.storageDiagnostics.draftCount) drafts", systemImage: "doc.text")
            }
        }
    }

    private var dictationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Voice lab")
                        .font(.headline)
                    Text(workspace.selectedProfile.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Preset", selection: Binding(
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
                .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
                .padding(16)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .textSelection(.enabled)

            if let errorMessage = transcriber.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else if transcriber.isProcessing {
                Text("Finishing transcript...")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text(workspace.selectedProfile.behaviorSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                Button(transcriber.isRecording ? "Stop" : "Record") {
                    if transcriber.isRecording {
                        transcriber.stop()
                    } else {
                        transcriber.start(profile: workspace.selectedProfile)
                    }
                }
                .buttonStyle(ShinsokuPrimaryButtonStyle())

                Button("Save") {
                    workspace.saveDraft(transcriber.transcript)
                }
                .buttonStyle(ShinsokuSecondaryButtonStyle())
                .disabled(!hasTranscript)

                Button("Copy") {
                    UIPasteboard.general.string = transcriber.transcript
                }
                .buttonStyle(ShinsokuSecondaryButtonStyle())
                .disabled(!hasTranscript)

                Button("Clear") {
                    transcriber.stop(resetTranscript: true)
                }
                .buttonStyle(ShinsokuSecondaryButtonStyle())
                .disabled(!hasTranscript && !transcriber.isRecording)
            }

            Button {
                workspace.saveDraft(transcriber.transcript)
                NotificationCenter.default.post(name: .shinsokuOpenDrafts, object: nil)
            } label: {
                Label("Save and review in Drafts", systemImage: "arrow.right.doc.on.clipboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!hasTranscript)
        }
        .shinsokuCard()
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Runtime")
                .font(.headline)

            statusRow(
                title: "Speech access",
                detail: transcriber.authorizationState.description,
                isGood: transcriber.authorizationState == .ready
            )
            statusRow(
                title: "Provider",
                detail: "\(runtimeProviderLabel) - \(workspace.providerStatus.summary)",
                isGood: workspace.providerStatus.ready
            )
            statusRow(
                title: "Shared storage",
                detail: workspace.storageDiagnostics.isUsingSharedDefaults ? "App and keyboard are sharing drafts." : "Fallback storage is active.",
                isGood: workspace.storageDiagnostics.isUsingSharedDefaults
            )

            if transcriber.authorizationState != .ready {
                Button("Request speech permissions") {
                    Task { await transcriber.requestPermissions() }
                }
                .buttonStyle(ShinsokuPrimaryButtonStyle())
            }
        }
        .shinsokuCard()
    }

    private var recentDraftsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent drafts")
                    .font(.headline)
                Spacer()
                Button("View all") {
                    NotificationCenter.default.post(name: .shinsokuOpenDrafts, object: nil)
                }
                .buttonStyle(.bordered)
            }

            if workspace.drafts.isEmpty {
                Text("No saved drafts yet. Record something above, then save it for keyboard insertion.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(workspace.drafts.prefix(3).enumerated()), id: \.element.id) { index, draft in
                    if index > 0 {
                        Divider()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(draft.text)
                            .lineLimit(3)
                        Text("\(profileTitle(for: draft.profileID)) - \(DisplayFormatting.relativeTimestamp(for: draft.updatedAt))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                }
            }
        }
        .shinsokuCard()
    }

    private var keyboardHandoffCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard handoff")
                .font(.headline)
            Text("Enable Shinsoku Keyboard and Full Access, then use it to insert drafts into any text field.")
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("Setup guide") {
                    NotificationCenter.default.post(name: .shinsokuOpenSettings, object: nil)
                }
                .buttonStyle(.bordered)

                Button("Open iOS Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.bordered)
            }
        }
        .shinsokuCard()
    }

    private var runtimeProviderLabel: String {
        NativeRuntimeMetadata.describe(
            providerName: workspace.providerConfig.activeRecognitionProvider.rawValue,
            postProcessingMode: workspace.effectivePostProcessingMode.rawValue
        ).providerLabel
    }

    private func profileTitle(for id: String) -> String {
        VoiceProfile.defaults.first(where: { $0.id == id })?.title ?? id
    }

    private func statusRow(title: String, detail: String, isGood: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isGood ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(isGood ? Color.green : Color.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statusChip(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground), in: Capsule())
    }
}

private struct ShinsokuPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(Color(.systemBackground))
            .background(Color.primary.opacity(configuration.isPressed ? 0.78 : 1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

private struct ShinsokuSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(.primary)
            .background(Color.primary.opacity(configuration.isPressed ? 0.14 : 0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(isEnabled ? 1 : 0.38)
    }
}

extension Notification.Name {
    static let shinsokuOpenDrafts = Notification.Name("shinsokuOpenDrafts")
    static let shinsokuOpenSettings = Notification.Name("shinsokuOpenSettings")
    static let shinsokuOpenHome = Notification.Name("shinsokuOpenHome")
}

private extension View {
    func shinsokuCard() -> some View {
        padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
