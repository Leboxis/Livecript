import Foundation
import SwiftData
import Testing

@testable import Livecript

/// Persistence checks that use a real on-disk store. The other store tests use an
/// in-memory container, which cannot prove that data survives a relaunch.
@Suite("Persistance sur disque")
struct StorePersistenceTests {
    private func makeStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("livecript-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Livecript.store")
    }

    @Test("Une réouverture conserve transcription, brouillon et vocabulaire")
    func reopenedStoreRetainsTranscriptAndDraft() async throws {
        let url = makeStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let saved = DraftSnapshot(id: UUID(), text: "Réunion de lundi.", localeIdentifier: "fr-FR", mode: .standard)
        let pending = DraftSnapshot(id: UUID(), text: "Brouillon l’été 🌞", localeIdentifier: "en-US", mode: .customVocabulary)

        do {
            let store = TranscriptStore(modelContainer: try StorageFactory.make(at: url))
            _ = try await store.saveTranscript(saved)
            try await store.saveDraft(pending)
            try await store.setVocabulary([.init(id: UUID(), phrase: "Livecript")])
        }

        let reopened = TranscriptStore(modelContainer: try StorageFactory.make(at: url))
        let transcripts = try await reopened.transcripts()

        #expect(transcripts.count == 1)
        #expect(transcripts.first?.id == saved.id)
        #expect(transcripts.first?.text == saved.text)
        #expect(transcripts.first?.localeIdentifier == "fr-FR")
        #expect(transcripts.first?.mode == .standard)
        #expect(try await reopened.loadDraft() == pending)
        #expect(try await reopened.vocabulary().map(\.phrase) == ["Livecript"])
    }

    @Test("Un renommage survit à la réouverture")
    func renamePersistsAcrossReload() async throws {
        let url = makeStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let draft = DraftSnapshot(id: UUID(), text: "Texte inchangé.", localeIdentifier: "fr-FR", mode: .standard)
        do {
            let store = TranscriptStore(modelContainer: try StorageFactory.make(at: url))
            _ = try await store.saveTranscript(draft)
            try await store.rename(id: draft.id, title: "Titre persistant")
        }

        let reopened = TranscriptStore(modelContainer: try StorageFactory.make(at: url))
        let transcripts = try await reopened.transcripts()

        // Renaming only changes the title and the modification date, never the text.
        #expect(transcripts.first?.title == "Titre persistant")
        #expect(transcripts.first?.text == draft.text)
        #expect((transcripts.first?.updatedAt ?? .distantPast) >= (transcripts.first?.createdAt ?? .distantFuture))
    }

    @Test("Un échec d'écriture est signalé et le brouillon précédent survit")
    func injectedWriteFailureKeepsDraft() async throws {
        let url = makeStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let draft = DraftSnapshot(id: UUID(), text: "Brouillon conservé.", localeIdentifier: "fr-FR", mode: .standard)

        let writable = TranscriptStore(modelContainer: try StorageFactory.make(at: url))
        try await writable.saveDraft(draft)
        #expect(try await writable.loadDraft() == draft)

        // Inject a write failure. Saving must throw instead of reporting success.
        let readOnly = TranscriptStore(modelContainer: try StorageFactory.make(at: url, allowsSave: false))
        await #expect(throws: (any Error).self) { try await readOnly.saveTranscript(draft) }

        // The failed save must not have created an entry nor destroyed the draft.
        #expect(try await writable.transcripts().isEmpty)
        #expect(try await writable.loadDraft() == draft)
    }
}