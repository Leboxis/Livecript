import SwiftUI
struct HistoryView: View {
    let store: TranscriptStore
    @Environment(HistoryRefresh.self) private var refresh
    @State private var records: [TranscriptSnapshot] = []
    @State private var errorMessage: String?
    @State private var pendingDeletion: TranscriptSnapshot?
    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView {
                        Label("Vos mots, ici", systemImage: "text.document")
                    } description: {
                        Text("Les transcriptions enregistrées depuis l'onglet Transcrire apparaîtront ici.")
                    }
                } else {
                    List {
                        ForEach(records) { record in
                            NavigationLink {
                                TranscriptDetailView(record: record, store: store)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(record.title)
                                        .font(.headline)
                                        .lineLimit(2)
                                    Text(record.createdAt, format: .dateTime.day().month(.wide).year().hour().minute())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(record.text)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 8)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { pendingDeletion = record } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button("Supprimer", systemImage: "trash", role: .destructive) { pendingDeletion = record }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Historique")
            .confirmationDialog(
                "Supprimer cette transcription ?",
                isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
                titleVisibility: .visible
            ) {
                Button("Supprimer", role: .destructive) { delete(pendingDeletion) }
            } message: {
                Text(pendingDeletion?.title ?? "")
            }
            .alert("Lecture impossible", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("Réessayer") { refresh.bump() }
                Button("Fermer", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
            .task(id: refresh.generation) { await reload() }
            .refreshable { await reload() }
        }
    }
    private func reload() async {
        do { records = try await store.transcripts() }
        catch { errorMessage = error.localizedDescription }
    }
    private func delete(_ record: TranscriptSnapshot?) {
        guard let record else { return }
        Task {
            do {
                try await store.delete(id: record.id)
                records.removeAll { $0.id == record.id }
                refresh.bump()
            } catch { errorMessage = error.localizedDescription }
        }
    }
}