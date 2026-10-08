import SwiftUI
import UIKit
struct TranscriptDetailView: View {
    let record: TranscriptSnapshot
    let store: TranscriptStore
    @Environment(HistoryRefresh.self) private var refresh
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var editedTitle = ""
    @State private var renaming = false
    @State private var deleting = false
    @State private var errorMessage: String?
    @State private var copied = false
    init(record: TranscriptSnapshot, store: TranscriptStore) {
        self.record = record; self.store = store; _title = State(initialValue: record.title)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(record.createdAt, format: .dateTime.day().month(.wide).year().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(record.text)
                    .font(.body)
                    .lineSpacing(8)
                    .textSelection(.enabled)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
        }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        // Copy and share live in their own bottom bar above the tab bar. Putting
        // them in the navigation toolbar made them collide with the inline title
        // and the overflow menu.
        .safeAreaInset(edge: .bottom) { actions }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Renommer", systemImage: "pencil") { editedTitle = title; renaming = true }
                    Button("Supprimer", systemImage: "trash", role: .destructive) { deleting = true }
                } label: { Image(systemName: "ellipsis") }.accessibilityLabel("Actions de la transcription")
            }
        }
        .alert("Renommer", isPresented: $renaming) {
            TextField("Titre", text: $editedTitle)
            Button("Annuler", role: .cancel) {}
            Button("Enregistrer") {
                Task {
                    do {
                        try await store.rename(id: record.id, title: editedTitle)
                        title = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        refresh.bump()
                    } catch { errorMessage = error.localizedDescription }
                }
            }
        }
        .confirmationDialog("Supprimer cette transcription ?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                Task {
                    do {
                        try await store.delete(id: record.id)
                        refresh.bump()
                        dismiss()
                    } catch { errorMessage = error.localizedDescription }
                }
            }
        }
        .alert("Action impossible", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }
    private var actions: some View {
        HStack(spacing: 16) {
            Button {
                UIPasteboard.general.string = record.text
                copied = true
            } label: {
                Label(copied ? "Copié" : "Copier", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .disabled(copied)
            ShareLink(item: record.text) {
                Label("Partager", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
        }
        .controlSize(.large)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(.regularMaterial)
    }
}