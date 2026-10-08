import Foundation
import Testing
@testable import Livecript
struct CoreTests {
    @Test func provisionalReplacement() {
        var a = TranscriptAccumulator(); let id = UUID(); a.beginSegment(id: id)
        a.receive(.init(segmentID: id, text: "Bonjour", isFinal: false))
        a.receive(.init(segmentID: id, text: "Bonjour tout", isFinal: false))
        a.receive(.init(segmentID: id, text: "Bonjour tout le monde", isFinal: true))
        #expect(a.displayText == "Bonjour tout le monde")
        #expect(a.provisionalText.isEmpty)
    }
    @Test func newSegmentAndStaleResult() {
        var a = TranscriptAccumulator(); let first = UUID(); a.beginSegment(id: first)
        a.receive(.init(segmentID: first, text: "Bonjour.", isFinal: true))
        let second = UUID(); a.beginSegment(id: second)
        a.receive(.init(segmentID: first, text: "Ancien", isFinal: true))
        a.receive(.init(segmentID: second, text: "Bonsoir, l’été 🌞.", isFinal: true))
        #expect(a.finalText == "Bonjour. Bonsoir, l’été 🌞.")
    }
    @Test func emptyFinalClearsProvisional() {
        var a = TranscriptAccumulator(); let id = UUID(); a.beginSegment(id: id)
        a.receive(.init(segmentID: id, text: "faux départ", isFinal: false))
        a.receive(.init(segmentID: id, text: "", isFinal: true))
        #expect(a.displayText.isEmpty)
    }
    @Test func vocabularyValidation() throws {
        #expect(throws: (any Error).self) { try VocabularyRules.validate([" "]) }
        #expect(throws: (any Error).self) { try VocabularyRules.validate(["Apple", " apple "]) }
        #expect(try VocabularyRules.validate(["  Livecript  "]) == ["Livecript"])
        #expect(try VocabularyRules.validate((0..<100).map { "Terme \($0)" }).count == 100)
        #expect(throws: (any Error).self) { try VocabularyRules.validate((0...100).map { "Terme \($0)" }) }
    }
    @Test func editVocabularyAtCapacityAllowed() throws {
        var atCapacity = (0..<100).map { "Terme \($0)" }
        #expect(try VocabularyRules.validate(atCapacity).count == 100)

        // Editing an existing term must stay possible once the limit is reached.
        atCapacity[42] = "  Terme remplacé  "
        let edited = try VocabularyRules.validate(atCapacity)
        #expect(edited.count == 100)
        #expect(edited[42] == "Terme remplacé")

        // Renaming a term onto an existing one is still a duplicate.
        atCapacity[42] = atCapacity[7]
        #expect(throws: (any Error).self) { try VocabularyRules.validate(atCapacity) }
    }
}
