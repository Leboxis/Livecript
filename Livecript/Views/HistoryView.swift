import SwiftUI
struct HistoryView: View {
    let store: TranscriptStore
    @State private var records: [TranscriptSnapshot] = []
    @State private var errorMessage: String?
    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView("Vos mots, ici", systemImage: "text.document", description: Text("Les transcriptions enregistrées apparaîtront ici."))
                } else {
                    List(records) { record in
                        NavigationLink {
                            TranscriptDetailView(record: record, store: store)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(record.title).font(.headline).lineLimit(2)
                                Text(record.createdAt, format: .dateTime.day().month().hour().minute()).font(.caption).foregroundStyle(.secondary)
                                Text(record.text).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                            }.padding(.vertical, 8)
                        }
                    }.listStyle(.plain)
                }
            }
            .navigationTitle("Historique")
            .task { await reload() }
            .refreshable { await reload() }
            .alert("Lecture impossible", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("Réessayer") { Task { await reload() } }
                Button("Fermer", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
        }
    }
    private func reload() async { do { records = try await store.transcripts() } catch { errorMessage = error.localizedDescription } }
}
