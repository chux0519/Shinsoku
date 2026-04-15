import Foundation

enum VoiceRecognitionProvider: String, CaseIterable, Codable, Identifiable {
    case androidSystem = "AndroidSystem"
    case openAiCompatible = "OpenAiCompatible"
    case soniox = "Soniox"
    case bailian = "Bailian"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .androidSystem:
            return "Apple Speech"
        case .openAiCompatible:
            return "OpenAI-Compatible"
        case .soniox:
            return "Soniox"
        case .bailian:
            return "Bailian"
        }
    }
}

enum TranscriptPostProcessingMode: String, CaseIterable, Codable, Identifiable {
    case disabled = "Disabled"
    case localCleanup = "LocalCleanup"
    case providerAssisted = "ProviderAssisted"

    var id: String { rawValue }
}

struct OpenAiProviderConfig: Codable, Equatable {
    var baseUrl: String = "https://api.openai.com/v1"
    var apiKey: String = ""
    var transcriptionModel: String = "gpt-4o-mini-transcribe"
    var postProcessingModel: String = "gpt-5.4-nano"
}

struct OpenAiPostProcessingConfig: Codable, Equatable {
    var baseUrl: String = "https://api.openai.com/v1"
    var apiKey: String = ""
    var model: String = "gpt-5.4-nano"
}

struct SonioxProviderConfig: Codable, Equatable {
    var url: String = "wss://stt-rt.soniox.com/transcribe-websocket"
    var apiKey: String = ""
    var model: String = "stt-rt-preview"
}

struct BailianProviderConfig: Codable, Equatable {
    var region: String = "cn-beijing"
    var url: String = "wss://dashscope.aliyuncs.com/api-ws/v1/inference/"
    var apiKey: String = ""
    var model: String = "fun-asr-realtime"
}

struct VoiceProviderConfig: Codable, Equatable {
    var activeRecognitionProvider: VoiceRecognitionProvider = .androidSystem
    var openAiRecognition: OpenAiProviderConfig = .init()
    var openAiPostProcessing: OpenAiPostProcessingConfig = .init()
    var soniox: SonioxProviderConfig = .init()
    var bailian: BailianProviderConfig = .init()
}

struct VoicePostProcessingConfig: Codable, Equatable {
    var mode: TranscriptPostProcessingMode = .localCleanup
}

struct VoiceRuntimeConfig: Equatable {
    var profile: VoiceProfile
    var providerConfig: VoiceProviderConfig
    var postProcessingConfig: VoicePostProcessingConfig
}

enum VoiceProviderConfigStore {
    static func loadProviderConfig() -> VoiceProviderConfig {
        let defaults = ShinsokuSharedStorage.defaults
        let legacyBaseUrl = defaults.string(forKey: ShinsokuSharedStorage.openAiAsrBaseUrlKey)
            ?? OpenAiProviderConfig().baseUrl
        let legacyApiKey = defaults.string(forKey: ShinsokuSharedStorage.openAiAsrApiKeyKey) ?? ""
        let legacyAsrModel = defaults.string(forKey: ShinsokuSharedStorage.openAiAsrTranscriptionModelKey)
            ?? OpenAiProviderConfig().transcriptionModel
        let legacyPostModel = defaults.string(forKey: ShinsokuSharedStorage.openAiPostModelKey)
            ?? OpenAiPostProcessingConfig().model

        return VoiceProviderConfig(
            activeRecognitionProvider: defaults.string(forKey: ShinsokuSharedStorage.activeRecognitionProviderKey)
                .flatMap(VoiceRecognitionProvider.init(rawValue:))
                ?? .androidSystem,
            openAiRecognition: OpenAiProviderConfig(
                baseUrl: defaults.string(forKey: ShinsokuSharedStorage.openAiAsrBaseUrlKey) ?? legacyBaseUrl,
                apiKey: defaults.string(forKey: ShinsokuSharedStorage.openAiAsrApiKeyKey) ?? legacyApiKey,
                transcriptionModel: defaults.string(forKey: ShinsokuSharedStorage.openAiAsrTranscriptionModelKey)
                    ?? legacyAsrModel,
                postProcessingModel: defaults.string(forKey: ShinsokuSharedStorage.openAiAsrPostProcessingModelKey)
                    ?? OpenAiProviderConfig().postProcessingModel
            ),
            openAiPostProcessing: OpenAiPostProcessingConfig(
                baseUrl: defaults.string(forKey: ShinsokuSharedStorage.openAiPostBaseUrlKey) ?? legacyBaseUrl,
                apiKey: defaults.string(forKey: ShinsokuSharedStorage.openAiPostApiKeyKey) ?? legacyApiKey,
                model: defaults.string(forKey: ShinsokuSharedStorage.openAiPostModelKey) ?? legacyPostModel
            ),
            soniox: SonioxProviderConfig(
                url: defaults.string(forKey: ShinsokuSharedStorage.sonioxUrlKey) ?? SonioxProviderConfig().url,
                apiKey: defaults.string(forKey: ShinsokuSharedStorage.sonioxApiKeyKey) ?? "",
                model: defaults.string(forKey: ShinsokuSharedStorage.sonioxModelKey) ?? SonioxProviderConfig().model
            ),
            bailian: BailianProviderConfig(
                region: defaults.string(forKey: ShinsokuSharedStorage.bailianRegionKey) ?? BailianProviderConfig().region,
                url: defaults.string(forKey: ShinsokuSharedStorage.bailianUrlKey) ?? BailianProviderConfig().url,
                apiKey: defaults.string(forKey: ShinsokuSharedStorage.bailianApiKeyKey) ?? "",
                model: defaults.string(forKey: ShinsokuSharedStorage.bailianModelKey) ?? BailianProviderConfig().model
            )
        )
    }

    static func saveProviderConfig(_ config: VoiceProviderConfig) {
        let defaults = ShinsokuSharedStorage.defaults
        defaults.set(config.activeRecognitionProvider.rawValue, forKey: ShinsokuSharedStorage.activeRecognitionProviderKey)
        defaults.set(config.openAiRecognition.baseUrl, forKey: ShinsokuSharedStorage.openAiAsrBaseUrlKey)
        defaults.set(config.openAiRecognition.apiKey, forKey: ShinsokuSharedStorage.openAiAsrApiKeyKey)
        defaults.set(config.openAiRecognition.transcriptionModel, forKey: ShinsokuSharedStorage.openAiAsrTranscriptionModelKey)
        defaults.set(config.openAiRecognition.postProcessingModel, forKey: ShinsokuSharedStorage.openAiAsrPostProcessingModelKey)
        defaults.set(config.openAiPostProcessing.baseUrl, forKey: ShinsokuSharedStorage.openAiPostBaseUrlKey)
        defaults.set(config.openAiPostProcessing.apiKey, forKey: ShinsokuSharedStorage.openAiPostApiKeyKey)
        defaults.set(config.openAiPostProcessing.model, forKey: ShinsokuSharedStorage.openAiPostModelKey)
        defaults.set(config.soniox.url, forKey: ShinsokuSharedStorage.sonioxUrlKey)
        defaults.set(config.soniox.apiKey, forKey: ShinsokuSharedStorage.sonioxApiKeyKey)
        defaults.set(config.soniox.model, forKey: ShinsokuSharedStorage.sonioxModelKey)
        defaults.set(config.bailian.region, forKey: ShinsokuSharedStorage.bailianRegionKey)
        defaults.set(config.bailian.url, forKey: ShinsokuSharedStorage.bailianUrlKey)
        defaults.set(config.bailian.apiKey, forKey: ShinsokuSharedStorage.bailianApiKeyKey)
        defaults.set(config.bailian.model, forKey: ShinsokuSharedStorage.bailianModelKey)
    }
}

enum VoiceRuntimeConfigStore {
    static func loadRuntimeConfig() -> VoiceRuntimeConfig {
        let providerConfig = VoiceProviderConfigStore.loadProviderConfig()
        let requestedMode = ShinsokuSharedStorage.defaults.string(forKey: ShinsokuSharedStorage.requestedPostProcessingModeKey)
            .flatMap(TranscriptPostProcessingMode.init(rawValue:))
            ?? .providerAssisted
        let effectiveMode = NativeVoiceRuntime.resolvePostProcessingMode(
            requestedMode: requestedMode,
            activeProvider: providerConfig.activeRecognitionProvider,
            openAiApiKey: providerConfig.openAiPostProcessing.apiKey
        )
        return VoiceRuntimeConfig(
            profile: VoiceProfileStore.loadSelectedProfile(),
            providerConfig: providerConfig,
            postProcessingConfig: VoicePostProcessingConfig(mode: effectiveMode)
        )
    }

    static func loadRequestedPostProcessingMode() -> TranscriptPostProcessingMode {
        ShinsokuSharedStorage.defaults.string(forKey: ShinsokuSharedStorage.requestedPostProcessingModeKey)
            .flatMap(TranscriptPostProcessingMode.init(rawValue:))
            ?? .providerAssisted
    }

    static func saveRequestedPostProcessingMode(_ mode: TranscriptPostProcessingMode) {
        ShinsokuSharedStorage.defaults.set(mode.rawValue, forKey: ShinsokuSharedStorage.requestedPostProcessingModeKey)
    }
}

struct ProviderRuntimeStatus {
    let ready: Bool
    let summary: String
    let detail: String
}

enum RecognitionProviderDiagnostics {
    static func status(_ config: VoiceProviderConfig) -> ProviderRuntimeStatus {
        switch config.activeRecognitionProvider {
        case .androidSystem:
            return ProviderRuntimeStatus(
                ready: true,
                summary: "on-device ready",
                detail: "Uses Apple Speech and on-device audio capture. No remote credentials required."
            )
        case .openAiCompatible:
            return buildRemoteStatus(
                providerName: "OpenAI-compatible",
                apiKey: config.openAiRecognition.apiKey,
                model: config.openAiRecognition.transcriptionModel,
                endpoint: config.openAiRecognition.baseUrl,
                allowedSchemes: ["http", "https"]
            )
        case .soniox:
            return buildRemoteStatus(
                providerName: "Soniox",
                apiKey: config.soniox.apiKey,
                model: config.soniox.model,
                endpoint: config.soniox.url,
                allowedSchemes: ["ws", "wss"]
            )
        case .bailian:
            return buildRemoteStatus(
                providerName: "Bailian",
                apiKey: config.bailian.apiKey,
                model: config.bailian.model,
                endpoint: config.bailian.url,
                allowedSchemes: ["ws", "wss"],
                extraIssues: config.bailian.region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? ["Region is missing."]
                    : []
            )
        }
    }

    static func requireReady(_ config: VoiceProviderConfig) -> String? {
        let status = status(config)
        return status.ready ? nil : status.detail
    }

    private static func buildRemoteStatus(
        providerName: String,
        apiKey: String,
        model: String,
        endpoint: String,
        allowedSchemes: Set<String>,
        extraIssues: [String] = []
    ) -> ProviderRuntimeStatus {
        var issues = extraIssues
        if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("API key is missing.")
        }
        if model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Model is missing.")
        }
        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedEndpoint.isEmpty {
            issues.append("Endpoint is missing.")
        } else if let scheme = URL(string: trimmedEndpoint)?.scheme?.lowercased(), !allowedSchemes.contains(scheme) {
            issues.append("Endpoint must use \(allowedSchemes.sorted().joined(separator: "/")).")
        }

        if issues.isEmpty {
            return ProviderRuntimeStatus(
                ready: true,
                summary: "credentials ready",
                detail: "\(providerName) is configured for remote recognition.\nEndpoint: \(trimmedEndpoint)"
            )
        }
        return ProviderRuntimeStatus(
            ready: false,
            summary: "configuration incomplete",
            detail: "\(providerName) is not ready: \(issues.joined(separator: " "))\nEndpoint: \(trimmedEndpoint)"
        )
    }
}

enum NativeVoiceRuntime {
    static func resolvePostProcessingMode(
        requestedMode: TranscriptPostProcessingMode,
        activeProvider: VoiceRecognitionProvider,
        openAiApiKey: String
    ) -> TranscriptPostProcessingMode {
        guard let resolved = NativeProfileBridge.resolvePostProcessingMode(
            requestedMode.rawValue,
            activeProviderName: activeProvider.rawValue,
            openAiApiKey: openAiApiKey
        ) else {
            if requestedMode == .disabled {
                return .disabled
            }
            if requestedMode == .providerAssisted &&
                openAiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .localCleanup
            }
            return requestedMode
        }
        return TranscriptPostProcessingMode(rawValue: resolved) ?? .localCleanup
    }
}

enum NativeTranscriptCleanup {
    static func cleanupTranscript(_ rawText: String) -> String {
        if let value = NativeProfileBridge.cleanupTranscript(rawText) {
            return value
        }
        return rawText
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
