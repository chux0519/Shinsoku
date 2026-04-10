import Foundation

@MainActor
final class IOSVoiceWorkspace: ObservableObject {
    @Published var selectedProfile: VoiceProfile = VoiceProfileStore.loadSelectedProfile()
    @Published var drafts: [StoredDraft] = DraftStore.loadDrafts()
    @Published var storageDiagnostics: SharedStorageDiagnostics = DraftStore.diagnostics()

    func refresh() {
        selectedProfile = VoiceProfileStore.loadSelectedProfile()
        drafts = DraftStore.loadDrafts()
        storageDiagnostics = DraftStore.diagnostics()
    }

    func selectProfile(_ profile: VoiceProfile) {
        selectedProfile = profile
        VoiceProfileStore.saveSelectedProfile(profile)
    }

    func saveDraft(_ text: String) {
        DraftStore.append(text: text, profileID: selectedProfile.id)
        refresh()
    }

    func deleteDraft(id: UUID) {
        DraftStore.remove(id: id)
        refresh()
    }

    func updateDraft(id: UUID, text: String, profile: VoiceProfile) {
        DraftStore.update(id: id, text: text, profileID: profile.id)
        refresh()
    }

    func clearDrafts() {
        DraftStore.clear()
        refresh()
    }

    func cycleProfile() {
        guard let currentIndex = VoiceProfile.defaults.firstIndex(of: selectedProfile) else {
            selectProfile(VoiceProfile.defaults[0])
            return
        }
        let nextIndex = (currentIndex + 1) % VoiceProfile.defaults.count
        selectProfile(VoiceProfile.defaults[nextIndex])
    }
}
