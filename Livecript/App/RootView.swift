import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var session: TranscriptionSession
    private let store: TranscriptStore
    let preferences: AppPreferences
    let service: AppleSpeechService
    init(container: ModelContainer, preferences: AppPreferences, service: AppleSpeechService) {
        let store = TranscriptStore(modelContainer: container)
        self.store = store; self.preferences = preferences; self.service = service
        _session = State(initialValue: TranscriptionSession(service: service, store: store))
    }
    var body: some View {
        TabView {
            Tab("Transcrire", systemImage: "waveform") {
                TranscribeView(session: session, store: store, preferences: preferences, service: service)
            }
            Tab("Historique", systemImage: "text.document") { HistoryView(store: store) }
            Tab("Réglages", systemImage: "slider.horizontal.3") { SettingsView(preferences: preferences, store: store) }
        }
        .tint(Color(red: 0.12, green: 0.58, blue: 0.47))
        .task { await session.restore() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { Task { await session.pause() } }
        }
    }
}
