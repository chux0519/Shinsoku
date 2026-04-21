import SwiftUI
import Combine
import UIKit

struct RootView: View {
    private enum Tab: Hashable {
        case home
        case drafts
        case settings
    }

    @EnvironmentObject private var workspace: IOSVoiceWorkspace
    @EnvironmentObject private var transcriber: SpeechTranscriber
    @EnvironmentObject private var flow: FlowSessionCoordinator
    @Environment(\.scenePhase) private var scenePhase
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
            switch (url.host, url.path) {
            case ("flow", "/start"):
                selectedTab = .home
                let request = FlowSessionStore.loadStartRequest()
                    ?? FlowSessionStore.requestStart(profileID: VoiceProfileStore.loadSelectedProfile().id)
                flow.start(request: request, transcriber: transcriber)
            case ("drafts", _):
                flow.dismissFinishedSession()
                selectedTab = .drafts
            case ("settings", _):
                flow.dismissFinishedSession()
                selectedTab = .settings
            default:
                flow.dismissFinishedSession()
                selectedTab = .home
            }
            workspace.refresh()
        }
        .fullScreenCover(isPresented: $flow.isPresented) {
            FlowSessionView()
                .environmentObject(flow)
                .environmentObject(transcriber)
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
        .onChange(of: scenePhase) { newValue in
            guard newValue == .active else { return }
            workspace.refresh()
            transcriber.refreshAuthorizationState()
            if let request = FlowSessionStore.loadStartRequest() {
                selectedTab = .home
                flow.start(request: request, transcriber: transcriber)
            }
        }
    }
}

@MainActor
final class FlowSessionCoordinator: ObservableObject {
    @Published var snapshot: FlowSessionSnapshot = FlowSessionStore.loadSnapshot()
    @Published var isPresented = false

    private var sessionID: UUID?
    private var activeProfile: VoiceProfile?
    private var didPersistFinalDraft = false
    private var startedAt: Date?
    private var monitor: Timer?
    private let sessionTimeout: TimeInterval = 300

    func start(request: FlowStartRequest, transcriber: SpeechTranscriber) {
        FlowSessionStore.clearStartRequest(id: request.id)
        transcriber.stop(resetTranscript: true)
        sessionID = request.id
        didPersistFinalDraft = false
        startedAt = .now
        activeProfile = VoiceProfile.defaults.first(where: { $0.id == request.profileID }) ?? VoiceProfileStore.loadSelectedProfile()
        snapshot = FlowSessionSnapshot(
            id: request.id,
            phase: .starting,
            profileID: activeProfile?.id ?? request.profileID,
            partialText: "",
            finalText: "",
            errorMessage: "",
            updatedAt: .now
        )
        FlowSessionStore.saveSnapshot(snapshot)
        isPresented = true
        startMonitor(transcriber: transcriber)

        Task { [weak self] in
            guard let self else { return }
            if transcriber.authorizationState != .ready {
                await transcriber.requestPermissions()
            }
            guard transcriber.authorizationState == .ready else {
                self.fail("Microphone permission is not ready.")
                return
            }
            transcriber.start(profile: self.activeProfile ?? VoiceProfileStore.loadSelectedProfile())
            self.publishFromTranscriber(transcriber)
        }
    }

    func stop(transcriber: SpeechTranscriber) {
        guard let sessionID else { return }
        FlowSessionStore.clearStopRequest(sessionID: sessionID)
        transcriber.stop()
        publishFromTranscriber(transcriber)
    }

    func dismiss() {
        isPresented = false
    }

    func dismissFinishedSession() {
        snapshot = FlowSessionStore.loadSnapshot()
        switch snapshot.phase {
        case .idle, .done, .failed:
            isPresented = false
        case .starting, .recording, .processing:
            break
        }
    }

    private func startMonitor(transcriber: SpeechTranscriber) {
        monitor?.invalidate()
        monitor = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self, weak transcriber] _ in
            Task { @MainActor [weak self, weak transcriber] in
                guard let self, let transcriber else { return }
                self.tick(transcriber: transcriber)
            }
        }
    }

    private func tick(transcriber: SpeechTranscriber) {
        guard let sessionID else {
            monitor?.invalidate()
            monitor = nil
            return
        }

        if let stopRequest = FlowSessionStore.loadStopRequest(), stopRequest.sessionID == sessionID {
            stop(transcriber: transcriber)
            return
        }

        if let startedAt,
           Date().timeIntervalSince(startedAt) > sessionTimeout,
           snapshot.phase == .recording || snapshot.phase == .processing || snapshot.phase == .starting {
            transcriber.stop()
            fail("Flow session timed out after \(Int(sessionTimeout))s.")
            return
        }

        publishFromTranscriber(transcriber)
    }

    private func publishFromTranscriber(_ transcriber: SpeechTranscriber) {
        guard let sessionID else { return }

        if let error = transcriber.errorMessage, !error.isEmpty {
            fail(error)
            return
        }

        let text = transcriber.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let phase: FlowSessionPhase
        if transcriber.isRecording {
            phase = .recording
        } else if transcriber.isProcessing {
            phase = .processing
        } else if !text.isEmpty {
            phase = .done
        } else {
            phase = snapshot.phase == .idle ? .starting : snapshot.phase
        }

        snapshot = FlowSessionSnapshot(
            id: sessionID,
            phase: phase,
            profileID: activeProfile?.id ?? snapshot.profileID,
            partialText: phase == .done ? "" : text,
            finalText: phase == .done ? text : snapshot.finalText,
            errorMessage: "",
            updatedAt: .now
        )
        FlowSessionStore.saveSnapshot(snapshot)

        if phase == .done {
            persistFinalDraftIfNeeded(text: text)
            finishMonitoring()
        }
    }

    private func fail(_ message: String) {
        guard let sessionID else { return }
        snapshot = FlowSessionSnapshot(
            id: sessionID,
            phase: .failed,
            profileID: activeProfile?.id ?? snapshot.profileID,
            partialText: snapshot.partialText,
            finalText: snapshot.finalText,
            errorMessage: message,
            updatedAt: .now
        )
        FlowSessionStore.saveSnapshot(snapshot)
        finishMonitoring()
    }

    private func persistFinalDraftIfNeeded(text: String) {
        guard !didPersistFinalDraft else { return }
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        DraftStore.append(text: normalized, profileID: activeProfile?.id ?? snapshot.profileID)
        UIPasteboard.general.string = normalized
        didPersistFinalDraft = true
    }

    private func finishMonitoring() {
        monitor?.invalidate()
        monitor = nil
        sessionID = nil
        activeProfile = nil
        startedAt = nil
    }
}

struct FlowSessionView: View {
    @EnvironmentObject private var flow: FlowSessionCoordinator
    @EnvironmentObject private var transcriber: SpeechTranscriber

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            Image(systemName: iconName)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.primary)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            if !previewText.isEmpty {
                Text(previewText)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 20)
            }

            Button {
                flow.stop(transcriber: transcriber)
            } label: {
                Text(stopButtonTitle)
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .foregroundStyle(Color(.systemBackground))
            .background(Color.primary.opacity(stopButtonDisabled ? 0.35 : 1), in: Capsule())
            .padding(.horizontal, 36)
            .disabled(stopButtonDisabled)

            Text(footnote)
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.vertical, 24)
        .background(.background)
    }

    private var iconName: String {
        switch flow.snapshot.phase {
        case .done:
            return "checkmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        case .processing:
            return "wand.and.stars"
        default:
            return "waveform"
        }
    }

    private var title: String {
        switch flow.snapshot.phase {
        case .starting:
            return "Starting Flow"
        case .recording:
            return "Listening"
        case .processing:
            return "Processing"
        case .done:
            return "Ready to Insert"
        case .failed:
            return "Flow Failed"
        case .idle:
            return "Flow"
        }
    }

    private var subtitle: String {
        switch flow.snapshot.phase {
        case .recording:
            return "Recording is active. Return to your previous app now."
        case .processing:
            return "Finalizing transcript and post-processing."
        case .done:
            return "Transcript is ready and copied to clipboard. Return to your text field; Shinsoku Keyboard can auto-insert if iOS keeps it active."
        case .failed:
            return flow.snapshot.errorMessage
        default:
            return "Preparing microphone and recognition."
        }
    }

    private var previewText: String {
        if !flow.snapshot.finalText.isEmpty {
            return flow.snapshot.finalText
        }
        return flow.snapshot.partialText
    }

    private var stopButtonTitle: String {
        switch flow.snapshot.phase {
        case .processing:
            return "Finishing"
        case .done:
            return "Finished"
        case .failed:
            return "Failed"
        default:
            return "Stop"
        }
    }

    private var stopButtonDisabled: Bool {
        flow.snapshot.phase == .done || flow.snapshot.phase == .failed || flow.snapshot.phase == .processing
    }

    private var footnote: String {
        switch flow.snapshot.phase {
        case .recording:
            return "Use the iOS top-left back indicator or edge swipe to return to the app you were editing. iOS does not allow Shinsoku to programmatically jump back to an arbitrary previous app."
        case .done:
            return "If iOS switches back to another keyboard after returning, use Paste from the clipboard. Third-party keyboards cannot force themselves to become active again."
        case .failed:
            return "Return to the keyboard and tap Mic to retry, or open Settings to adjust the provider."
        default:
            return "Shinsoku needs to start microphone capture in the main app. Once Listening appears, go back to your original app and keep speaking."
        }
    }
}
