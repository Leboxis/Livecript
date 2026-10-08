import Foundation
import Speech

/// Single source of truth for every Speech setting used by Livecript.
///
/// Livecript only builds local modules (`SpeechTranscriber` and
/// `DictationTranscriber`) on top of assets installed by Apple. It never uses
/// `SFSpeechRecognizer`, the only Speech API able to fall back to server
/// recognition, so an unsupported locale or a missing model is reported before
/// the microphone is opened instead of quietly sending audio off device.
struct SpeechConfigurationPolicy {
    enum ModuleKind: Equatable, Sendable {
        case standardTranscriber
        case dictationTranscriber
    }

    let localeIdentifier: String
    let mode: RecognitionMode
    let vocabulary: [String]

    var locale: Locale { Locale(identifier: localeIdentifier) }

    var moduleKind: ModuleKind {
        switch mode {
        case .standard: .standardTranscriber
        case .customVocabulary: .dictationTranscriber
        }
    }

    /// `contextualStrings` is documented for the dictation module only. The
    /// specification forbids claiming it influences `SpeechTranscriber`, so the
    /// vocabulary is dropped in standard mode instead of being sent and ignored.
    var appliesVocabulary: Bool { moduleKind == .dictationTranscriber }

    /// Always false. Kept explicit and covered by a test so that adding a
    /// networked recognition path later is a deliberate, visible change.
    var allowsRemoteRecognition: Bool { false }

    func resolvedVocabulary() throws -> [String] {
        guard appliesVocabulary else { return [] }
        return try VocabularyRules.validate(vocabulary)
    }

    func applyVocabulary(to context: AnalysisContext) throws {
        guard appliesVocabulary else { return }
        context.contextualStrings[.general] = try resolvedVocabulary()
    }

    /// Availability check performed before any capture. Returning the resolved
    /// locale keeps the caller from ever using an unsupported identifier.
    func validateSupport(isModuleAvailable: Bool, resolvedLocale: Locale?) throws -> Locale {
        guard isModuleAvailable else {
            throw LivecriptError.invalid("La reconnaissance locale n’est pas disponible sur cet appareil.")
        }
        guard let resolvedLocale else {
            throw LivecriptError.invalid("Cette langue n’est pas prise en charge par la reconnaissance locale.")
        }
        return resolvedLocale
    }
}