import SwiftData
import SwiftUI
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var session: TranscriptionSession
    @State private var historyRefresh = HistoryRefresh()
    @State private var tab: Tab = .transcribe
    private let store: TranscriptStore
    let preferences: AppPreferences
    let service: AppleSpeechService
    private enum Tab: Hashable {
        case transcribe, history, settings
    }
    init(container: ModelContainer, preferences: AppPreferences, service: AppleSpeechService) {
        let store = TranscriptStore(modelContainer: container)
        self.store = store; self.preferences = preferences; self.service = service
        _session = State(initialValue: TranscriptionSession(service: service, store: store))
    }
    var body: some View {
        TabView(selection: $tab) {
            Tab("Transcrire", systemImage: "waveform") {
                TranscribeView(session: session, store: store, preferences: preferences, service: service)
            }
            .tag(Tab.transcribe)
            Tab("Historique", systemImage: "text.document") {
                HistoryView(store: store)
            }
            .tag(Tab.history)
            Tab("Réglages", systemImage: "slider.horizontal.3") {
                SettingsView(preferences: preferences, store: store)
            }
            .tag(Tab.settings)
        }
        .tint(Color(red: 0.12, green: 0.58, blue: 0.47))
        .environment(historyRefresh)
        .task { await session.restore() }
        .onChange(of: tab) { _, new in
            // Returning to the tab is the only reliable signal that the list may
            // be stale: the view is already alive, so `.task` never re-runs.
            if new == .history { historyRefresh.bump() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { Task { await session.pause() } }
        }
    }
}