import Foundation
import Speech
import Testing

@testable import Livecript

@Suite("Politique de reconnaissance locale")
struct SpeechConfigurationPolicyTests {
    private static func policy(_ mode: RecognitionMode, vocabulary: [String] = []) -> SpeechConfigurationPolicy {
        .init(localeIdentifier: "fr-FR", mode: mode, vocabulary: vocabulary)
    }

    @Test("Le mode personnalisé transmet le vocabulaire validé au module")
    func customModePassesVocabulary() throws {
        let policy = Self.policy(.customVocabulary, vocabulary: ["  Livecript  ", "Tour Eiffel"])

        #expect(policy.moduleKind == .dictationTranscriber)
        #expect(policy.appliesVocabulary)
        #expect(try policy.resolvedVocabulary() == ["Livecript", "Tour Eiffel"])

        let context = AnalysisContext()
        try policy.applyVocabulary(to: context)
        #expect(context.contextualStrings[.general] == ["Livecript", "Tour Eiffel"])
    }

    @Test("Le mode standard ignore le vocabulaire")
    func standardModeOmitsVocabulary() throws {
        let policy = Self.policy(.standard, vocabulary: ["Livecript"])

        #expect(policy.moduleKind == .standardTranscriber)
        #expect(!policy.appliesVocabulary)
        #expect(try policy.resolvedVocabulary().isEmpty)

        // contextualStrings is documented for the dictation module only, so an
        // invalid vocabulary must not break standard mode either.
        let context = AnalysisContext()
        try Self.policy(.standard, vocabulary: ["Apple", " apple "]).applyVocabulary(to: context)
        #expect(context.contextualStrings[.general].isEmpty)
    }

    @Test("Aucun mode n'autorise la reconnaissance serveur")
    func bothModesDisallowServer() {
        let localModules: [SpeechConfigurationPolicy.ModuleKind] = [.standardTranscriber, .dictationTranscriber]

        for mode in RecognitionMode.allCases {
            let policy = Self.policy(mode, vocabulary: ["Livecript"])
            #expect(!policy.allowsRemoteRecognition)
            // The policy can only ever select an on-device module.
            #expect(localModules.contains(policy.moduleKind))
        }
    }

    @Test("Une langue ou un module indisponible échoue avant la capture")
    func offlineMissingModelFailsBeforeCapture() throws {
        let policy = Self.policy(.standard)

        // Unavailable module: Airplane mode with no installed model.
        #expect(throws: LivecriptError.self) {
            try policy.validateSupport(isModuleAvailable: false, resolvedLocale: Locale(identifier: "fr-FR"))
        }
        // Unsupported locale.
        #expect(throws: LivecriptError.self) {
            try policy.validateSupport(isModuleAvailable: true, resolvedLocale: nil)
        }
        // Supported: the resolved locale is handed back, never the raw identifier.
        let resolved = try policy.validateSupport(isModuleAvailable: true, resolvedLocale: Locale(identifier: "fr-FR"))
        #expect(resolved.identifier == "fr-FR")
    }

    @Test("Un vocabulaire invalide est refusé avant la capture")
    func invalidVocabularyRejectedBeforeCapture() {
        let duplicate = Self.policy(.customVocabulary, vocabulary: ["Apple", " apple "])
        #expect(throws: LivecriptError.self) { try duplicate.resolvedVocabulary() }

        let blank = Self.policy(.customVocabulary, vocabulary: ["   "])
        #expect(throws: LivecriptError.self) { try blank.resolvedVocabulary() }

        let tooMany = Self.policy(.customVocabulary, vocabulary: (0...100).map { "Terme \($0)" })
        #expect(throws: LivecriptError.self) { try tooMany.resolvedVocabulary() }
    }
}