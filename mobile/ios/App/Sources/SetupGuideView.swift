import SwiftUI
import UIKit

struct SetupGuideView: View {
    @EnvironmentObject private var workspace: IOSVoiceWorkspace
    @EnvironmentObject private var transcriber: SpeechTranscriber

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                permissionCard
                keyboardCard
                draftCard
                troubleshootingCard
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Setup guide")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            transcriber.refreshAuthorizationState()
            workspace.refresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Use Shinsoku on iOS")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
            Text("Record in the app, then insert from the keyboard extension when you are ready.")
                .foregroundStyle(.secondary)
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("1. Grant speech access")
                .font(.headline)
            guideRow(
                title: "Speech recognition",
                detail: transcriber.authorizationState.description,
                isComplete: transcriber.authorizationState == .ready
            )
            HStack(spacing: 12) {
                Button("Request permissions") {
                    Task { await transcriber.requestPermissions() }
                }
                .buttonStyle(.borderedProminent)

                Button("Open iOS Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.bordered)
            }
        }
        .setupGuideCard()
    }

    private var keyboardCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("2. Enable the keyboard")
                .font(.headline)
            guideInstruction("Open iOS Settings > General > Keyboard > Keyboards.")
            guideInstruction("Add Shinsoku Keyboard.")
            guideInstruction("Enable Full Access if you want the keyboard to open the app and keep shared drafts in sync.")
        }
        .setupGuideCard()
    }

    private var draftCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("3. Save a draft in the app")
                .font(.headline)
            guideRow(
                title: "Shared drafts",
                detail: workspace.storageDiagnostics.draftCount > 0 ? "\(workspace.storageDiagnostics.draftCount) draft(s) ready for the keyboard." : "No drafts yet. Record a phrase and tap Save draft.",
                isComplete: workspace.storageDiagnostics.draftCount > 0
            )
            Text("The keyboard does not record on iOS. It reads the latest saved drafts and inserts them with profile-aware suffix behavior.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("Open drafts") {
                    NotificationCenter.default.post(name: .shinsokuOpenDrafts, object: nil)
                }
                .buttonStyle(.bordered)

                Button("Open home") {
                    NotificationCenter.default.post(name: .shinsokuOpenHome, object: nil)
                }
                .buttonStyle(.bordered)
            }
        }
        .setupGuideCard()
    }

    private var troubleshootingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Troubleshooting")
                .font(.headline)
            guideInstruction("If the keyboard shows fallback storage, reopen the app and verify the App Group is available.")
            guideInstruction("If dictation stays empty, check microphone and speech recognition permissions in iOS Settings.")
            guideInstruction("If the keyboard cannot open the app, Full Access is probably still disabled.")
        }
        .setupGuideCard()
    }

    private func guideRow(title: String, detail: String, isComplete: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isComplete ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func guideInstruction(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•")
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private extension View {
    func setupGuideCard() -> some View {
        padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
