import SwiftUI

struct DraftEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var workspace: IOSVoiceWorkspace

    let draft: StoredDraft

    @State private var text: String
    @State private var selectedProfile: VoiceProfile

    init(draft: StoredDraft) {
        self.draft = draft
        _text = State(initialValue: draft.text)
        _selectedProfile = State(initialValue: VoiceProfile.defaults.first(where: { $0.id == draft.profileID }) ?? VoiceProfile.defaults[0])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Draft") {
                    TextEditor(text: $text)
                        .frame(minHeight: 220)
                }

                Section("Profile") {
                    Picker("Profile", selection: $selectedProfile) {
                        ForEach(VoiceProfile.defaults) { profile in
                            Text(profile.title).tag(profile)
                        }
                    }
                }
            }
            .navigationTitle("Edit draft")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        workspace.updateDraft(id: draft.id, text: text, profile: selectedProfile)
                        dismiss()
                    }
                }
            }
        }
    }
}
