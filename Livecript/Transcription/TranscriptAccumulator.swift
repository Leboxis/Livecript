import Foundation
struct TranscriptAccumulator {
    private(set) var finalText = ""
    private(set) var provisionalText = ""
    private var segmentID: UUID?
    init(text: String = "") { finalText = text }
    var displayText: String { Self.join(finalText, provisionalText) }
    mutating func beginSegment(id: UUID) { segmentID = id; provisionalText = "" }
    mutating func receive(_ event: TranscriptEvent) {
        guard event.segmentID == segmentID else { return }
        if event.isFinal {
            finalText = Self.join(finalText, event.text)
            provisionalText = ""
        } else { provisionalText = event.text }
    }
    static func join(_ left: String, _ right: String) -> String {
        let a = left.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = right.trimmingCharacters(in: .whitespacesAndNewlines)
        if a.isEmpty { return b }; if b.isEmpty { return a }
        return a + " " + b
    }
}
