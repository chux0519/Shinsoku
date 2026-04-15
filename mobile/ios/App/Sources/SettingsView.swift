import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var workspace: IOSVoiceWorkspace
    @EnvironmentObject private var transcriber: SpeechTranscriber

    @State private var recognitionProvider: VoiceRecognitionProvider = .androidSystem
    @State private var requestedPostProcessingMode: TranscriptPostProcessingMode = .providerAssisted
    @State private var openAiAsrBaseUrl = ""
    @State private var openAiAsrApiKey = ""
    @State private var openAiAsrModel = ""
    @State private var openAiPostBaseUrl = ""
    @State private var openAiPostApiKey = ""
    @State private var openAiPostModel = ""
    @State private var sonioxUrl = ""
    @State private var sonioxApiKey = ""
    @State private var sonioxModel = ""
    @State private var bailianRegion = ""
    @State private var bailianUrl = ""
    @State private var bailianApiKey = ""
    @State private var bailianModel = ""
    @State private var saveMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                runtimeCard
                workflowCard
                providerCard
                keyboardCard
                setupCard
                draftsCard
                linksCard
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Settings")
        .onAppear {
            workspace.refresh()
            transcriber.refreshAuthorizationState()
            syncEditableState()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Settings")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
            Text("Configure presets, shared storage, and remote provider credentials from one place.")
                .foregroundStyle(.secondary)
        }
    }

    private var runtimeCard: some View {
        let metadata = NativeRuntimeMetadata.describe(
            providerName: workspace.providerConfig.activeRecognitionProvider.rawValue,
            postProcessingMode: workspace.effectivePostProcessingMode.rawValue
        )

        return VStack(alignment: .leading, spacing: 12) {
            Text("Runtime status")
                .font(.headline)
            LabeledContent("Selected profile", value: workspace.selectedProfile.title)
            LabeledContent("Recognition backend", value: metadata.providerLabel)
            LabeledContent("Post-processing", value: metadata.postProcessingLabel)
            LabeledContent("Provider status", value: workspace.providerStatus.summary)
            Text(workspace.providerStatus.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
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
            Text(workspace.selectedProfile.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(workspace.selectedProfile.behaviorSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Divider()
            Text("Transform prompt")
                .font(.subheadline.weight(.semibold))
            Text(workspace.selectedProfile.transformSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let preview = NativeTransformPromptBuilder.build(
                rawTranscript: workspace.selectedProfile.mode == .translateChineseToEnglish
                    ? "你好，Shinsoku。"
                    : "sample transcript",
                transform: workspace.selectedProfile.transform
            ) {
                Text(preview.requestFormat == .singleUserMessage ? "Single prompt preview" : "System prompt preview")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(preview.displayPreview)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .textSelection(.enabled)
            }
        }
        .shinsokuSettingsCard()
    }

    private var providerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recognition and post-processing")
                .font(.headline)

            Picker("Recognition backend", selection: $recognitionProvider) {
                ForEach(VoiceRecognitionProvider.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.menu)

            Picker("Post-processing", selection: $requestedPostProcessingMode) {
                ForEach(TranscriptPostProcessingMode.allCases) { mode in
                    Text(postProcessingTitle(mode)).tag(mode)
                }
            }
            .pickerStyle(.menu)

            Group {
                Text("OpenAI-compatible ASR")
                    .font(.subheadline.weight(.semibold))
                providerField("Base URL", text: $openAiAsrBaseUrl, prompt: "https://api.openai.com/v1")
                SecureField("API key", text: $openAiAsrApiKey)
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                providerField("Transcription model", text: $openAiAsrModel, prompt: "gpt-4o-mini-transcribe")
            }

            Group {
                Text("OpenAI-compatible post-processing")
                    .font(.subheadline.weight(.semibold))
                providerField("Base URL", text: $openAiPostBaseUrl, prompt: "https://api.openai.com/v1")
                SecureField("API key", text: $openAiPostApiKey)
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                providerField("Model", text: $openAiPostModel, prompt: "gpt-5.4-nano")
            }

            Group {
                Text("Soniox streaming")
                    .font(.subheadline.weight(.semibold))
                providerField("WebSocket URL", text: $sonioxUrl, prompt: "wss://stt-rt.soniox.com/transcribe-websocket")
                SecureField("API key", text: $sonioxApiKey)
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                providerField("Model", text: $sonioxModel, prompt: "stt-rt-preview")
            }

            Group {
                Text("Bailian streaming")
                    .font(.subheadline.weight(.semibold))
                providerField("Region", text: $bailianRegion, prompt: "cn-beijing")
                providerField("WebSocket URL", text: $bailianUrl, prompt: "wss://dashscope.aliyuncs.com/api-ws/v1/inference/")
                SecureField("API key", text: $bailianApiKey)
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                providerField("Model", text: $bailianModel, prompt: "fun-asr-realtime")
            }

            Button("Save provider settings") {
                workspace.saveProviderConfig(
                    VoiceProviderConfig(
                        activeRecognitionProvider: recognitionProvider,
                        openAiRecognition: OpenAiProviderConfig(
                            baseUrl: openAiAsrBaseUrl.trimmingCharacters(in: .whitespacesAndNewlines),
                            apiKey: openAiAsrApiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                            transcriptionModel: openAiAsrModel.trimmingCharacters(in: .whitespacesAndNewlines),
                            postProcessingModel: workspace.providerConfig.openAiRecognition.postProcessingModel
                        ),
                        openAiPostProcessing: OpenAiPostProcessingConfig(
                            baseUrl: openAiPostBaseUrl.trimmingCharacters(in: .whitespacesAndNewlines),
                            apiKey: openAiPostApiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                            model: openAiPostModel.trimmingCharacters(in: .whitespacesAndNewlines)
                        ),
                        soniox: SonioxProviderConfig(
                            url: sonioxUrl.trimmingCharacters(in: .whitespacesAndNewlines),
                            apiKey: sonioxApiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                            model: sonioxModel.trimmingCharacters(in: .whitespacesAndNewlines)
                        ),
                        bailian: BailianProviderConfig(
                            region: bailianRegion.trimmingCharacters(in: .whitespacesAndNewlines),
                            url: bailianUrl.trimmingCharacters(in: .whitespacesAndNewlines),
                            apiKey: bailianApiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                            model: bailianModel.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    )
                )
                workspace.saveRequestedPostProcessingMode(requestedPostProcessingMode)
                saveMessage = "Saved."
                syncEditableState()
            }
            .buttonStyle(.borderedProminent)

            if let saveMessage {
                Text(saveMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
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

    private func providerField(_ title: String, text: Binding<String>, prompt: String) -> some View {
        TextField(title, text: text, prompt: Text(prompt))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textFieldStyle(.roundedBorder)
    }

    private func postProcessingTitle(_ mode: TranscriptPostProcessingMode) -> String {
        switch mode {
        case .disabled:
            return "Disabled"
        case .localCleanup:
            return "Local cleanup"
        case .providerAssisted:
            return "Provider-assisted"
        }
    }

    private func syncEditableState() {
        let providerConfig = workspace.providerConfig
        recognitionProvider = providerConfig.activeRecognitionProvider
        requestedPostProcessingMode = workspace.requestedPostProcessingMode
        openAiAsrBaseUrl = providerConfig.openAiRecognition.baseUrl
        openAiAsrApiKey = providerConfig.openAiRecognition.apiKey
        openAiAsrModel = providerConfig.openAiRecognition.transcriptionModel
        openAiPostBaseUrl = providerConfig.openAiPostProcessing.baseUrl
        openAiPostApiKey = providerConfig.openAiPostProcessing.apiKey
        openAiPostModel = providerConfig.openAiPostProcessing.model
        sonioxUrl = providerConfig.soniox.url
        sonioxApiKey = providerConfig.soniox.apiKey
        sonioxModel = providerConfig.soniox.model
        bailianRegion = providerConfig.bailian.region
        bailianUrl = providerConfig.bailian.url
        bailianApiKey = providerConfig.bailian.apiKey
        bailianModel = providerConfig.bailian.model
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
