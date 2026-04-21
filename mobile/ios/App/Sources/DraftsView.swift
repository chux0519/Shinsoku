import SwiftUI
import UIKit

struct DraftsView: View {
    @EnvironmentObject private var workspace: IOSVoiceWorkspace
    @State private var editingDraft: StoredDraft?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                summaryCard
                draftList
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Drafts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    NotificationCenter.default.post(name: .shinsokuOpenHome, object: nil)
                } label: {
                    Label("Home", systemImage: "chevron.left")
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    workspace.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh drafts")

                if !workspace.drafts.isEmpty {
                    Button(role: .destructive) {
                        workspace.clearDrafts()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Clear all drafts")
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Draft library")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
            Text("Review the app-generated drafts that the keyboard can insert into the active text field.")
                .foregroundStyle(.secondary)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard queue")
                .font(.headline)
            HStack(spacing: 8) {
                summaryChip(title: "\(workspace.drafts.count) drafts")
                summaryChip(title: workspace.selectedProfile.title)
                summaryChip(title: workspace.storageDiagnostics.isUsingSharedDefaults ? "Shared ready" : "Fallback")
            }
            Text("The newest draft appears first. Edit text here if recognition needs a small correction before inserting from the keyboard.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .shinsokuDraftCard()
    }

    @ViewBuilder
    private var draftList: some View {
        if workspace.drafts.isEmpty {
            emptyState
        } else {
            VStack(spacing: 12) {
                ForEach(workspace.drafts) { draft in
                    draftRow(for: draft)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.badge.plus")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                Text("No drafts yet")
                    .font(.title3.weight(.semibold))
                Text("Go back Home, record a phrase, then save it as a draft for keyboard insertion.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                NotificationCenter.default.post(name: .shinsokuOpenHome, object: nil)
            } label: {
                Label("Back to Home", systemImage: "chevron.left")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .shinsokuDraftCard()
    }

    private func draftRow(for draft: StoredDraft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(profileTitle(for: draft.profileID))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(draft.text)
                        .foregroundStyle(.primary)
                        .lineLimit(6)
                        .textSelection(.enabled)
                }
                Spacer()
                Text(DisplayFormatting.relativeTimestamp(for: draft.updatedAt))
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 16) {
                Button {
                    editingDraft = draft
                } label: {
                    Label("Edit", systemImage: "square.and.pencil")
                }

                Button {
                    UIPasteboard.general.string = draft.text
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }

                Spacer()

                Button(role: .destructive) {
                    workspace.deleteDraft(id: draft.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .font(.footnote.weight(.medium))
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .shinsokuDraftCard()
    }

    private func profileTitle(for id: String) -> String {
        VoiceProfile.defaults.first(where: { $0.id == id })?.title ?? id
    }

    private func summaryChip(title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground), in: Capsule())
    }
}

private extension View {
    func shinsokuDraftCard() -> some View {
        padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
