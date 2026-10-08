import Foundation
import SwiftData

@ModelActor actor TranscriptStore {
    private func commit() throws {
        do { try modelContext.save() } catch { modelContext.rollback(); throw error }
    }
    func saveDraft(_ draft: DraftSnapshot) throws {
        for old in try modelContext.fetch(FetchDescriptor<StoredDraft>()) { modelContext.delete(old) }
        modelContext.insert(StoredDraft(draft)); try commit()
    }
    func loadDraft() throws -> DraftSnapshot? {
        try modelContext.fetch(FetchDescriptor<StoredDraft>()).first.map {
            DraftSnapshot(id: $0.id, text: $0.text, localeIdentifier: $0.localeIdentifier, mode: RecognitionMode(rawValue: $0.modeRaw) ?? .standard)
        }
    }
    func discardDraft() throws {
        for old in try modelContext.fetch(FetchDescriptor<StoredDraft>()) { modelContext.delete(old) }
        try commit()
    }
    func saveTranscript(_ draft: DraftSnapshot) throws -> UUID {
        guard !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LivecriptError.invalid("La transcription est vide.") }
        let id = draft.id
        let descriptor = FetchDescriptor<StoredTranscript>(predicate: #Predicate { $0.id == id })
        if let old = try modelContext.fetch(descriptor).first { old.text = draft.text; old.updatedAt = .now }
        else { modelContext.insert(StoredTranscript(draft: draft)) }
        for old in try modelContext.fetch(FetchDescriptor<StoredDraft>()) where old.id == id { modelContext.delete(old) }
        try commit(); return id
    }
    func transcripts() throws -> [TranscriptSnapshot] {
        try modelContext.fetch(FetchDescriptor<StoredTranscript>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])).map {
            TranscriptSnapshot(id: $0.id, title: $0.title, text: $0.text, createdAt: $0.createdAt, updatedAt: $0.updatedAt, localeIdentifier: $0.localeIdentifier, mode: RecognitionMode(rawValue: $0.modeRaw) ?? .standard)
        }
    }
    func rename(id: UUID, title: String) throws {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw LivecriptError.invalid("Le titre ne peut pas être vide.") }
        if let record = try modelContext.fetch(FetchDescriptor<StoredTranscript>(predicate: #Predicate { $0.id == id })).first {
            record.title = name; record.updatedAt = .now; try commit()
        }
    }
    func delete(id: UUID) throws {
        for record in try modelContext.fetch(FetchDescriptor<StoredTranscript>(predicate: #Predicate { $0.id == id })) { modelContext.delete(record) }
        try commit()
    }
    func vocabulary() throws -> [VocabularyEntry] {
        try modelContext.fetch(FetchDescriptor<VocabularyTerm>(sortBy: [SortDescriptor(\.phrase)])).map { .init(id: $0.id, phrase: $0.phrase) }
    }
    func setVocabulary(_ entries: [VocabularyEntry]) throws {
        let phrases = try VocabularyRules.validate(entries.map(\.phrase))
        for old in try modelContext.fetch(FetchDescriptor<VocabularyTerm>()) { modelContext.delete(old) }
        for (entry, phrase) in zip(entries, phrases) { modelContext.insert(VocabularyTerm(.init(id: entry.id, phrase: phrase))) }
        try commit()
    }
}
