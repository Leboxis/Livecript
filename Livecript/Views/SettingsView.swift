import SwiftUI
struct SettingsView: View {
    @Bindable var preferences: AppPreferences
    let store: TranscriptStore
    @State private var entries: [VocabularyEntry] = []
    @State private var locales: [String] = []
    @State private var phrase = ""
    @State private var editingID: UUID?
    @State private var editorVisible = false
    @State private var errorMessage: String?
    @State private var resourceService = AppleSpeechService()
    @State private var resourceTask: Task<Void, Never>?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Apparence", selection: $preferences.theme) { ForEach(AppTheme.allCases) { Text($0.title).tag($0) } }
                    Picker("Mode", selection: $preferences.mode) { ForEach(RecognitionMode.allCases) { Text($0.title).tag($0) } }
                    Picker("Langue", selection: $preferences.localeIdentifier) {
                        if !locales.contains(preferences.localeIdentifier) { Text("Français · à vérifier").tag(preferences.localeIdentifier) }
                        ForEach(locales, id: \.self) { identifier in
                            Text(Locale(identifier: "fr").localizedString(forIdentifier: identifier) ?? identifier).tag(identifier)
                        }
                    }
                } footer: { Text("Ces choix s’appliquent à la prochaine transcription. Standard utilise SpeechTranscriber ; le vocabulaire personnalisé utilise la dictée locale Apple.") }
                Section {
                    ForEach(entries) { entry in
                        Button(entry.phrase) { editingID = entry.id; phrase = entry.phrase; editorVisible = true }.foregroundStyle(.primary)
                    }.onDelete { offsets in
                        let remaining = entries.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
                        persist(remaining)
                    }
                    Button("Ajouter une expression", systemImage: "plus") { editingID = nil; phrase = ""; editorVisible = true }.disabled(entries.count >= 100)
                } header: { Text("Vocabulaire · \(entries.count)/100") }
                  footer: { Text("Privilégiez un ou deux mots. Ces expressions favorisent la reconnaissance en mode Vocabulaire personnalisé, sans garantir chaque résultat.") }
                Section("Modèle linguistique") {
                    Text(resourceService.resourceMessage).foregroundStyle(.secondary)
                    if let progress = resourceService.downloadProgress { ProgressView(value: progress) }
                    if resourceTask != nil {
                        Button("Annuler") { resourceTask?.cancel() }
                    } else {
                        Button("Préparer le modèle") { prepareModel() }
                    }
                }
                Section {
                    Label("Transcription sur cet appareil", systemImage: "lock.shield")
                    Text("Un premier téléchargement du modèle peut être nécessaire. Aucun audio n’est conservé. Les transcriptions restent dans l’application jusqu’à leur partage ou suppression.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Réglages")
            .task { do { entries = try await store.vocabulary() } catch { errorMessage = error.localizedDescription } }
            .task(id: preferences.mode) { locales = await AppleSpeechService.supportedLocales(mode: preferences.mode) }
            .onChange(of: preferences.mode) { _, _ in resourceTask?.cancel(); resourceService.resourceMessage = "Modèle à vérifier" }
            .onChange(of: preferences.localeIdentifier) { _, _ in resourceTask?.cancel(); resourceService.resourceMessage = "Modèle à vérifier" }
            .alert(editingID == nil ? "Nouvelle expression" : "Modifier l’expression", isPresented: $editorVisible) {
                TextField("Expression", text: $phrase)
                Button("Annuler", role: .cancel) {}
                Button("Enregistrer") {
                    var changed = entries
                    if let id = editingID, let index = changed.firstIndex(where: { $0.id == id }) { changed[index].phrase = phrase }
                    else { changed.append(.init(id: UUID(), phrase: phrase)) }
                    persist(changed)
                }
            }
            .alert("Action impossible", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
        }
    }
    private func persist(_ changed: [VocabularyEntry]) {
        Task { do { try await store.setVocabulary(changed); entries = try await store.vocabulary() } catch { errorMessage = error.localizedDescription } }
    }
    private func prepareModel() {
        let configuration = RecognitionConfiguration(localeIdentifier: preferences.localeIdentifier, mode: preferences.mode, vocabulary: entries.map(\.phrase))
        resourceTask = Task {
            defer { resourceTask = nil }
            do { try await resourceService.prepare(configuration) }
            catch is CancellationError { resourceService.resourceMessage = "Préparation annulée" }
            catch { errorMessage = error.localizedDescription }
        }
    }
}
