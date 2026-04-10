import SwiftUI

struct DraftsView: View {
    @EnvironmentObject private var workspace: IOSVoiceWorkspace
    @State private var editingDraft: StoredDraft?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                summaryCard

                if workspace.drafts.isEmpty {
                    VStack(spacing: 16) {
                        ContentUnavailableView(
                            "No drafts",
                            systemImage: "waveform.badge.magnifyingglass",
                            description: Text("Create a draft in the app, then insert it from the keyboard.")
                        )
                        Button("Go to Home") {
                            NotificationCenter.default.post(name: .shinsokuOpenHome, object: nil)
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, minHeight: 260)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else {
                    VStack(spacing: 12) {
                        ForEach(workspace.drafts) { draft in
                            draftRow(for: draft)
                        }
                    }
                }                
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Drafts")
        .toolbar {
            if !workspace.drafts.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear all", role: .destructive) {
                        workspace.clearDrafts()
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh") {
                    workspace.refresh()
                }
            }
        }
        .sheet(item: $editingDraft) { draft in
            DraftEditorView(draft: draft)
                .environmentObject(workspace)
        }
        .onAppear {
            workspace.refresh()
        }
    }

    private func profileTitle(for id: String) -> String {
        VoiceProfile.defaults.first(where: { $0.id == id })?.title ?? id
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Draft library")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
            Text("Edit, remove, or keep voice drafts ready for the keyboard extension.")
                .foregroundStyle(.secondary)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Library status")
                .font(.headline)
            HStack(spacing: 10) {
                summaryChip(title: "\(workspace.drafts.count) drafts")
                summaryChip(title: workspace.selectedProfile.title)
                summaryChip(title: workspace.storageDiagnostics.isUsingSharedDefaults ? "Shared ready" : "Fallback")
            }
            HStack(spacing: 12) {
                Button("Open setup guide") {
                    NotificationCenter.default.post(name: .shinsokuOpenSettings, object: nil)
                }
                .buttonStyle(.bordered)

                Button("Go to Home") {
                    NotificationCenter.default.post(name: .shinsokuOpenHome, object: nil)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func draftRow(for draft: StoredDraft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(profileTitle(for: draft.profileID))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(draft.text)
                        .foregroundStyle(.primary)
                        .lineLimit(5)
                }
                Spacer()
                Text(DisplayFormatting.relativeTimestamp(for: draft.updatedAt))
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 10) {
                Button {
                    editingDraft = draft
                } label: {
                    Label("Edit", systemImage: "square.and.pencil")
                }
                .buttonStyle(.plain)

                Spacer()

                Button(role: .destructive) {
                    workspace.deleteDraft(id: draft.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.plain)
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func summaryChip(title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground), in: Capsule())
    }
}
