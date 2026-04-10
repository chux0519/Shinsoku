import SwiftUI
import UIKit

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
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    editorCard
                    profileCard
                    metadataCard
                    actionsCard
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edit draft")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveDraft()
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Draft editor")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
            Text("Refine the saved text before sending it back through the keyboard extension.")
                .foregroundStyle(.secondary)
        }
    }

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Text")
                .font(.headline)
            TextEditor(text: $text)
                .frame(minHeight: 220)
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            Text("\(characterCount) characters")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .draftEditorCard()
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile")
                .font(.headline)
            Picker("Profile", selection: $selectedProfile) {
                ForEach(VoiceProfile.defaults) { profile in
                    Text(profile.title).tag(profile)
                }
            }
            .pickerStyle(.menu)
            Text(selectedProfile.mode.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .draftEditorCard()
    }

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metadata")
                .font(.headline)
            LabeledContent("Created", value: DisplayFormatting.absoluteTimestamp(for: draft.createdAt))
            LabeledContent("Last updated", value: DisplayFormatting.absoluteTimestamp(for: draft.updatedAt))
            LabeledContent("Original profile", value: VoiceProfile.defaults.first(where: { $0.id == draft.profileID })?.title ?? draft.profileID)
        }
        .draftEditorCard()
    }

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)
            HStack(spacing: 12) {
                Button("Save changes") {
                    saveDraft()
                }
                .buttonStyle(.borderedProminent)

                Button("Copy text") {
                    UIPasteboard.general.string = text
                }
                .buttonStyle(.bordered)

                ShareLink(item: text) {
                    Text("Share")
                }
                .buttonStyle(.bordered)

                Button("Delete draft", role: .destructive) {
                    workspace.deleteDraft(id: draft.id)
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .draftEditorCard()
    }

    private var characterCount: Int {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    private func saveDraft() {
        workspace.updateDraft(id: draft.id, text: text, profile: selectedProfile)
        dismiss()
    }
}

private extension View {
    func draftEditorCard() -> some View {
        padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
