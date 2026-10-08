import Foundation
import SwiftData
import Testing
@testable import Livecript
struct StoreTests {
    func store() throws -> TranscriptStore { TranscriptStore(modelContainer: try StorageFactory.make(inMemory: true)) }
    @Test func repeatedSaveAndRename() async throws {
        let s = try store(); let d = DraftSnapshot(id: UUID(), text: "Bonjour le monde", localeIdentifier: "fr-FR", mode: .standard)
        try await s.saveDraft(d); _ = try await s.saveTranscript(d); _ = try await s.saveTranscript(d)
        #expect(try await s.transcripts().count == 1)
        try await s.rename(id: d.id, title: "Réunion")
        #expect(try await s.transcripts().first?.title == "Réunion")
        #expect(try await s.transcripts().first?.text == d.text)
        await #expect(throws: (any Error).self) { try await s.rename(id: d.id, title: "  ") }
    }
    @Test func draftAndVocabularyRoundTrip() async throws {
        let s = try store(); let d = DraftSnapshot(id: UUID(), text: "l’été 🌞", localeIdentifier: "fr-FR", mode: .customVocabulary)
        try await s.saveDraft(d); #expect(try await s.loadDraft() == d)
        try await s.setVocabulary([.init(id: UUID(), phrase: " Livecript ")])
        #expect(try await s.vocabulary().map(\.phrase) == ["Livecript"])
        try await s.discardDraft(); #expect(try await s.loadDraft() == nil)
    }
    @Test func deleteOnlySelected() async throws {
        let s = try store(); let first = DraftSnapshot(id: UUID(), text: "Premier", localeIdentifier: "fr-FR", mode: .standard)
        let second = DraftSnapshot(id: UUID(), text: "Second", localeIdentifier: "fr-FR", mode: .standard)
        _ = try await s.saveTranscript(first); _ = try await s.saveTranscript(second)
        #expect(try await s.transcripts().first?.id == second.id)
        try await s.delete(id: first.id)
        #expect(try await s.transcripts().map(\.id) == [second.id])
    }
}
