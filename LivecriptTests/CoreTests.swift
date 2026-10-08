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
}
