import Foundation

enum RecognitionMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case standard, customVocabulary
    var id: String { rawValue }
    var title: String { self == .standard ? "Standard" : "Vocabulaire personnalisé" }
}
struct RecognitionConfiguration: Sendable, Equatable {
    let localeIdentifier: String
    let mode: RecognitionMode
    let vocabulary: [String]
}
struct TranscriptEvent: Sendable {
    let segmentID: UUID
    let text: String
    let isFinal: Bool
}
struct DraftSnapshot: Sendable, Equatable {
    let id: UUID
    let text: String
    let localeIdentifier: String
    let mode: RecognitionMode
}
struct TranscriptSnapshot: Sendable, Identifiable {
    let id: UUID
    let title: String
    let text: String
    let createdAt: Date
    let updatedAt: Date
    let localeIdentifier: String
    let mode: RecognitionMode
}
struct VocabularyEntry: Sendable, Identifiable, Equatable {
    let id: UUID
    var phrase: String
}
enum LivecriptError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { switch self { case .invalid(let message): message } }
}
