import SwiftUI

struct DraftsView: View {
    @EnvironmentObject private var workspace: IOSVoiceWorkspace
    @State private var editingDraft: StoredDraft?

    var body: some View {
        List {
            if workspace.drafts.isEmpty {
                ContentUnavailableView(
                    "No drafts",
                    systemImage: "waveform.badge.magnifyingglass",
                    description: Text("Create a draft in the app, then insert it from the keyboard.")
                )
            } else {
                ForEach(workspace.drafts) { draft in
                    Button {
                        editingDraft = draft
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(draft.text)
                                .foregroundStyle(.primary)
                                .lineLimit(4)
                            Text("\(profileTitle(for: draft.profileID)) · \(DisplayFormatting.relativeTimestamp(for: draft.updatedAt))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        workspace.deleteDraft(id: workspace.drafts[index].id)
                    }
                }
            }
        }
        .navigationTitle("Drafts")
        .toolbar {
            if !workspace.drafts.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear all", role: .destructive) {
                        workspace.clearDrafts()
                    }
                }
            }
        }
        .sheet(item: $editingDraft) { draft in
            DraftEditorView(draft: draft)
                .environmentObject(workspace)
        }
    }

    private func profileTitle(for id: String) -> String {
        VoiceProfile.defaults.first(where: { $0.id == id })?.title ?? id
    }
}
