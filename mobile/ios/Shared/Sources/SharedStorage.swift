import Foundation

enum ShinsokuSharedStorage {
    static let appGroupID = "group.net.potafree.shinsoku"
    static let sharedDefaults = UserDefaults(suiteName: appGroupID)
    static let defaults = sharedDefaults ?? .standard
    static let isUsingFallbackDefaults = sharedDefaults == nil

    static let selectedProfileKey = "selectedProfileID"
    static let draftsKey = "drafts"
    static let requestedPostProcessingModeKey = "requestedPostProcessingMode"
    static let activeRecognitionProviderKey = "activeRecognitionProvider"
    static let openAiAsrBaseUrlKey = "openAiAsrBaseUrl"
    static let openAiAsrApiKeyKey = "openAiAsrApiKey"
    static let openAiAsrTranscriptionModelKey = "openAiAsrTranscriptionModel"
    static let openAiAsrPostProcessingModelKey = "openAiAsrPostProcessingModel"
    static let openAiPostBaseUrlKey = "openAiPostBaseUrl"
    static let openAiPostApiKeyKey = "openAiPostApiKey"
    static let openAiPostModelKey = "openAiPostModel"
    static let sonioxUrlKey = "sonioxUrl"
    static let sonioxApiKeyKey = "sonioxApiKey"
    static let sonioxModelKey = "sonioxModel"
    static let bailianRegionKey = "bailianRegion"
    static let bailianUrlKey = "bailianUrl"
    static let bailianApiKeyKey = "bailianApiKey"
    static let bailianModelKey = "bailianModel"
    static let flowSessionKey = "flowSession"
    static let flowStartRequestKey = "flowStartRequest"
    static let flowStopRequestKey = "flowStopRequest"
}

struct SharedStorageDiagnostics {
    let appGroupID: String
    let isUsingSharedDefaults: Bool
    let draftCount: Int
}

struct StoredDraft: Codable, Equatable, Identifiable {
    let id: UUID
    var text: String
    var profileID: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        text: String,
        profileID: String,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.text = text
        self.profileID = profileID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum VoiceProfileStore {
    static func loadSelectedProfile() -> VoiceProfile {
        let storedID = ShinsokuSharedStorage.defaults.string(forKey: ShinsokuSharedStorage.selectedProfileKey)
        return VoiceProfile.defaults.first(where: { $0.id == storedID }) ?? VoiceProfile.defaults[0]
    }

    static func saveSelectedProfile(_ profile: VoiceProfile) {
        let normalizedID = NativeVoiceProfiles.identifyBuiltIn(profile) ?? profile.id
        ShinsokuSharedStorage.defaults.set(normalizedID, forKey: ShinsokuSharedStorage.selectedProfileKey)
    }
}

enum DraftStore {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()
    private static let maxDraftCount = 20

    static func loadDrafts() -> [StoredDraft] {
        guard let data = ShinsokuSharedStorage.defaults.data(forKey: ShinsokuSharedStorage.draftsKey) else {
            return []
        }
        return (try? decoder.decode([StoredDraft].self, from: data)) ?? []
    }

    static func saveDrafts(_ drafts: [StoredDraft]) {
        let trimmed = Array(drafts.prefix(maxDraftCount))
        guard let data = try? encoder.encode(trimmed) else { return }
        ShinsokuSharedStorage.defaults.set(data, forKey: ShinsokuSharedStorage.draftsKey)
    }

    static func append(text: String, profileID: String) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        var drafts = loadDrafts()
        let now = Date()
        drafts.insert(StoredDraft(text: normalized, profileID: profileID, createdAt: now, updatedAt: now), at: 0)
        saveDrafts(drafts)
    }

    static func update(id: UUID, text: String, profileID: String) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            remove(id: id)
            return
        }
        var drafts = loadDrafts()
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        drafts[index].text = normalized
        drafts[index].profileID = profileID
        drafts[index].updatedAt = .now
        saveDrafts(drafts)
    }

    static func remove(id: UUID) {
        saveDrafts(loadDrafts().filter { $0.id != id })
    }

    static func clear() {
        ShinsokuSharedStorage.defaults.removeObject(forKey: ShinsokuSharedStorage.draftsKey)
    }

    static func diagnostics() -> SharedStorageDiagnostics {
        SharedStorageDiagnostics(
            appGroupID: ShinsokuSharedStorage.appGroupID,
            isUsingSharedDefaults: !ShinsokuSharedStorage.isUsingFallbackDefaults,
            draftCount: loadDrafts().count
        )
    }
}

enum FlowSessionPhase: String, Codable {
    case idle
    case starting
    case recording
    case processing
    case done
    case failed
}

struct FlowSessionSnapshot: Codable, Equatable {
    var id: UUID
    var phase: FlowSessionPhase
    var profileID: String
    var partialText: String
    var finalText: String
    var errorMessage: String
    var updatedAt: Date

    static let idle = FlowSessionSnapshot(
        id: UUID(),
        phase: .idle,
        profileID: VoiceProfile.defaults[0].id,
        partialText: "",
        finalText: "",
        errorMessage: "",
        updatedAt: .distantPast
    )
}

struct FlowStartRequest: Codable, Equatable {
    var id: UUID
    var profileID: String
    var createdAt: Date
}

struct FlowStopRequest: Codable, Equatable {
    var sessionID: UUID
    var createdAt: Date
}

enum FlowSessionStore {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func loadSnapshot() -> FlowSessionSnapshot {
        guard let data = ShinsokuSharedStorage.defaults.data(forKey: ShinsokuSharedStorage.flowSessionKey),
              let snapshot = try? decoder.decode(FlowSessionSnapshot.self, from: data) else {
            return .idle
        }
        return snapshot
    }

    static func saveSnapshot(_ snapshot: FlowSessionSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        ShinsokuSharedStorage.defaults.set(data, forKey: ShinsokuSharedStorage.flowSessionKey)
    }

    static func requestStart(profileID: String) -> FlowStartRequest {
        let request = FlowStartRequest(id: UUID(), profileID: profileID, createdAt: .now)
        if let data = try? encoder.encode(request) {
            ShinsokuSharedStorage.defaults.set(data, forKey: ShinsokuSharedStorage.flowStartRequestKey)
        }
        saveSnapshot(FlowSessionSnapshot(
            id: request.id,
            phase: .starting,
            profileID: profileID,
            partialText: "",
            finalText: "",
            errorMessage: "",
            updatedAt: .now
        ))
        return request
    }

    static func loadStartRequest() -> FlowStartRequest? {
        guard let data = ShinsokuSharedStorage.defaults.data(forKey: ShinsokuSharedStorage.flowStartRequestKey) else {
            return nil
        }
        return try? decoder.decode(FlowStartRequest.self, from: data)
    }

    static func clearStartRequest(id: UUID) {
        guard loadStartRequest()?.id == id else { return }
        ShinsokuSharedStorage.defaults.removeObject(forKey: ShinsokuSharedStorage.flowStartRequestKey)
    }

    static func requestStop(sessionID: UUID) {
        let request = FlowStopRequest(sessionID: sessionID, createdAt: .now)
        guard let data = try? encoder.encode(request) else { return }
        ShinsokuSharedStorage.defaults.set(data, forKey: ShinsokuSharedStorage.flowStopRequestKey)
    }

    static func loadStopRequest() -> FlowStopRequest? {
        guard let data = ShinsokuSharedStorage.defaults.data(forKey: ShinsokuSharedStorage.flowStopRequestKey) else {
            return nil
        }
        return try? decoder.decode(FlowStopRequest.self, from: data)
    }

    static func clearStopRequest(sessionID: UUID) {
        guard loadStopRequest()?.sessionID == sessionID else { return }
        ShinsokuSharedStorage.defaults.removeObject(forKey: ShinsokuSharedStorage.flowStopRequestKey)
    }

    static func reset() {
        ShinsokuSharedStorage.defaults.removeObject(forKey: ShinsokuSharedStorage.flowStartRequestKey)
        ShinsokuSharedStorage.defaults.removeObject(forKey: ShinsokuSharedStorage.flowStopRequestKey)
        saveSnapshot(.idle)
    }
}
