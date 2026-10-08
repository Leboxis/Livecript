import SwiftUI
import SwiftData

@main struct LivecriptApp: App {
    @State private var preferences = AppPreferences()
    @State private var service = AppleSpeechService()
    private let storage: Result<ModelContainer, Error> = Result { try StorageFactory.make() }
    var body: some Scene {
        WindowGroup {
            switch storage {
            case .success(let container):
                RootView(container: container, preferences: preferences, service: service)
                    .preferredColorScheme(preferences.theme.scheme)
            case .failure(let error):
                ContentUnavailableView("Stockage indisponible", systemImage: "externaldrive.badge.exclamationmark", description: Text("Vos données n’ont pas été supprimées. Relancez l’application.\n\(error.localizedDescription)"))
            }
        }
    }
}
