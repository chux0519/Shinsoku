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
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    UIApplication.shared.shinsokuDismissKeyboard()
                    NotificationCenter.default.post(name: .shinsokuOpenHome, object: nil)
                } label: {
                    Label("Home", systemImage: "chevron.left")
                }
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.shinsokuDismissKeyboard()
                }
            }
        }
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
            LabeledContent("Shared storage") {
                Text(workspace.storageDiagnostics.isUsingSharedDefaults ? "Ready" : "Fallback")
                    .foregroundStyle(workspace.storageDiagnostics.isUsingSharedDefaults ? Color.secondary : Color.red)
            }
            Text(workspace.storageDiagnostics.appGroupID)
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .shinsokuSettingsCard()
    }

    private var workflowCard: some View {
        let transformEnabled = workspace.selectedProfile.transform.enabled
        let canPreviewTransform = transformEnabled && requestedPostProcessingMode == .providerAssisted

        return VStack(alignment: .leading, spacing: 12) {
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

            if transformEnabled && requestedPostProcessingMode != .providerAssisted {
                Divider()
                Text("Transform prompt is available for this preset when post-processing is set to Provider-assisted.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if canPreviewTransform, let preview = NativeTransformPromptBuilder.build(
                rawTranscript: workspace.selectedProfile.mode == .translateChineseToEnglish
                    ? "你好，Shinsoku。"
                    : "sample transcript",
                transform: workspace.selectedProfile.transform
            ) {
                Divider()
                Text("Transform prompt")
                    .font(.subheadline.weight(.semibold))
                Text(workspace.selectedProfile.transformSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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

            if recognitionProvider == .androidSystem {
                Text("Apple Speech uses the on-device iOS speech recognizer and does not require a provider key.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if recognitionProvider == .openAiCompatible {
                Text("OpenAI-compatible ASR")
                    .font(.subheadline.weight(.semibold))
                providerField("Base URL", text: $openAiAsrBaseUrl, prompt: "https://api.openai.com/v1")
                providerSecureField("API key", text: $openAiAsrApiKey)
                providerField("Transcription model", text: $openAiAsrModel, prompt: "gpt-4o-mini-transcribe")
            }

            if requestedPostProcessingMode == .providerAssisted {
                Text("OpenAI-compatible post-processing")
                    .font(.subheadline.weight(.semibold))
                Text("Used for cleanup, translation, and custom prompt transforms. This can point to a different vendor from your ASR backend.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                providerField("Base URL", text: $openAiPostBaseUrl, prompt: "https://api.openai.com/v1")
                providerSecureField("API key", text: $openAiPostApiKey)
                providerField("Model", text: $openAiPostModel, prompt: "gpt-5.4-nano")
            } else if requestedPostProcessingMode == .localCleanup {
                Text("Local cleanup runs without a network model. Provider prompt settings are hidden until Provider-assisted is selected.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if recognitionProvider == .soniox {
                Text("Soniox streaming")
                    .font(.subheadline.weight(.semibold))
                providerField("WebSocket URL", text: $sonioxUrl, prompt: "wss://stt-rt.soniox.com/transcribe-websocket")
                providerSecureField("API key", text: $sonioxApiKey)
                providerField("Model", text: $sonioxModel, prompt: "stt-rt-preview")
            }

            if recognitionProvider == .bailian {
                Text("Bailian streaming")
                    .font(.subheadline.weight(.semibold))
                providerField("Region", text: $bailianRegion, prompt: "cn-beijing")
                providerField("WebSocket URL", text: $bailianUrl, prompt: "wss://dashscope.aliyuncs.com/api-ws/v1/inference/")
                providerSecureField("API key", text: $bailianApiKey)
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

            Button("Open iOS Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .buttonStyle(.bordered)
        }
        .shinsokuSettingsCard()
    }

    private func providerField(_ title: String, text: Binding<String>, prompt: String) -> some View {
        TextField(title, text: text, prompt: Text(prompt))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textFieldStyle(.roundedBorder)
    }

    private func providerSecureField(_ title: String, text: Binding<String>) -> some View {
        SecureField(title, text: text, prompt: Text(title))
            .textContentType(.password)
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
}

private extension View {
    func shinsokuSettingsCard() -> some View {
        padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private extension UIApplication {
    func shinsokuDismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
