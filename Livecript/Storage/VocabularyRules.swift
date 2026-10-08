import Foundation
struct VocabularyRules {
    static func validate(_ phrases: [String]) throws -> [String] {
        guard phrases.count <= 100 else { throw LivecriptError.invalid("100 expressions maximum.") }
        var seen = Set<String>()
        return try phrases.map { raw in
            let phrase = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !phrase.isEmpty else { throw LivecriptError.invalid("Saisissez un mot ou une expression.") }
            guard seen.insert(phrase.lowercased()).inserted else { throw LivecriptError.invalid("Cette expression existe déjà.") }
            return phrase
        }
    }
}
