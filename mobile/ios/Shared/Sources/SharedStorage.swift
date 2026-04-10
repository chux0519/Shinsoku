import Foundation

enum ShinsokuSharedStorage {
    static let appGroupID = "group.com.shinsoku.mobile"
    static let defaults = UserDefaults(suiteName: appGroupID) ?? .standard

    fileprivate static let selectedProfileKey = "selectedProfileID"
    fileprivate static let draftsKey = "drafts"
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
        ShinsokuSharedStorage.defaults.set(profile.id, forKey: ShinsokuSharedStorage.selectedProfileKey)
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

    static func remove(id: UUID) {
        saveDrafts(loadDrafts().filter { $0.id != id })
    }

    static func clear() {
        ShinsokuSharedStorage.defaults.removeObject(forKey: ShinsokuSharedStorage.draftsKey)
    }
}
