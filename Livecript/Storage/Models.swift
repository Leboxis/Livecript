import Foundation
import SwiftData

enum LivecriptSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [StoredTranscript.self, StoredDraft.self, VocabularyTerm.self] }
    @Model final class StoredTranscript {
        @Attribute(.unique) var id: UUID
        var title: String
        var text: String
        var createdAt: Date
        var updatedAt: Date
        var localeIdentifier: String
        var modeRaw: String
        init(draft: DraftSnapshot) {
            id = draft.id; text = draft.text; title = String(draft.text.prefix(60))
            createdAt = .now; updatedAt = .now; localeIdentifier = draft.localeIdentifier; modeRaw = draft.mode.rawValue
        }
    }
    @Model final class StoredDraft {
        @Attribute(.unique) var id: UUID
        var text: String
        var localeIdentifier: String
        var modeRaw: String
        init(_ draft: DraftSnapshot) { id = draft.id; text = draft.text; localeIdentifier = draft.localeIdentifier; modeRaw = draft.mode.rawValue }
    }
    @Model final class VocabularyTerm {
        @Attribute(.unique) var id: UUID
        var phrase: String
        init(_ entry: VocabularyEntry) { id = entry.id; phrase = entry.phrase }
    }
}
typealias StoredTranscript = LivecriptSchemaV1.StoredTranscript
typealias StoredDraft = LivecriptSchemaV1.StoredDraft
typealias VocabularyTerm = LivecriptSchemaV1.VocabularyTerm
enum LivecriptMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [LivecriptSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
enum StorageFactory {
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: LivecriptSchemaV1.self)
        if inMemory {
            return try ModelContainer(for: schema, migrationPlan: LivecriptMigrationPlan.self,
                                      configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        }
        // SwiftData creates the store file itself at its default location, but
        // the Application Support directory must already exist — ensuring it
        // here avoids a misleading "stockage indisponible" screen even though
        // the container is writable. Never pre-create anything at the store
        // file path itself: a directory there makes the SQLite store impossible
        // to open (SwiftData error 1).
        if let base = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                   appropriateFor: nil, create: true) {
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        }
        return try ModelContainer(for: schema, migrationPlan: LivecriptMigrationPlan.self,
                                  configurations: ModelConfiguration(schema: schema, cloudKitDatabase: .none))
    }

    /// On-disk container at an explicit location, used to prove that transcripts
    /// and drafts survive relaunches. `allowsSave: false` injects a write failure
    /// so recovery paths can be exercised without corrupting real data.
    static func make(at url: URL, allowsSave: Bool = true) throws -> ModelContainer {
        let schema = Schema(versionedSchema: LivecriptSchemaV1.self)
        let configuration = ModelConfiguration("Livecript", schema: schema, url: url,
                                               allowsSave: allowsSave, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: LivecriptMigrationPlan.self, configurations: configuration)
    }
}
