import AVFoundation
import Foundation
import Observation
import Speech

@MainActor @Observable final class AppleSpeechService: SpeechService {
    var resourceMessage = "Modèle à vérifier"
    var downloadProgress: Double?
    var preparing = false
    @ObservationIgnored private var analyzer: SpeechAnalyzer?
    @ObservationIgnored private var transcriber: SpeechTranscriber?
    @ObservationIgnored private var dictation: DictationTranscriber?
    @ObservationIgnored private var capture = MicrophoneCapture()
    @ObservationIgnored private var format: AVAudioFormat?
    @ObservationIgnored private var inputs: AsyncStream<AnalyzerInput>.Continuation?
    @ObservationIgnored private var events: AsyncThrowingStream<SpeechEvent, Error>.Continuation?
    @ObservationIgnored private var feeding: Task<Void, Error>?
    @ObservationIgnored private var results: Task<Void, Error>?
    @ObservationIgnored private var notifications: [NSObjectProtocol] = []

    static func supportedLocales(mode: RecognitionMode) async -> [String] {
        let locales = mode == .standard ? await SpeechTranscriber.supportedLocales : await DictationTranscriber.supportedLocales
        return locales.map(\.identifier).sorted()
    }
    func prepare(_ configuration: RecognitionConfiguration) async throws {
        guard !preparing else { throw LivecriptError.invalid("Une préparation est déjà en cours.") }
        preparing = true; defer { preparing = false; downloadProgress = nil }
        resourceMessage = "Vérification du modèle…"
        let policy = SpeechConfigurationPolicy(localeIdentifier: configuration.localeIdentifier,
                                               mode: configuration.mode,
                                               vocabulary: configuration.vocabulary)
        do {
            let modules: [any SpeechModule]
            switch policy.moduleKind {
            case .standardTranscriber:
                let resolved = try policy.validateSupport(isModuleAvailable: SpeechTranscriber.isAvailable,
                                                         resolvedLocale: await SpeechTranscriber.supportedLocale(equivalentTo: policy.locale))
                let t = SpeechTranscriber(locale: resolved, transcriptionOptions: [], reportingOptions: [.volatileResults], attributeOptions: [])
                transcriber = t; dictation = nil; modules = [t]
            case .dictationTranscriber:
                let resolved = try policy.validateSupport(isModuleAvailable: true,
                                                         resolvedLocale: await DictationTranscriber.supportedLocale(equivalentTo: policy.locale))
                let t = DictationTranscriber(locale: resolved, contentHints: [], transcriptionOptions: [], reportingOptions: [.volatileResults], attributeOptions: [])
                dictation = t; transcriber = nil; modules = [t]
            }
            try Task.checkCancellation()
            if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
                resourceMessage = "Téléchargement du modèle…"
                let progress = Task { [weak self] in
                    while !Task.isCancelled {
                        self?.downloadProgress = request.progress.fractionCompleted
                        try? await Task.sleep(for: .milliseconds(150))
                    }
                }
                defer { progress.cancel() }
                try await request.downloadAndInstall()
            }
            try Task.checkCancellation()
            let instance = SpeechAnalyzer(modules: modules)
            if policy.appliesVocabulary {
                let context = AnalysisContext()
                try policy.applyVocabulary(to: context)
                try await instance.setContext(context)
            }
            guard let audioFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules) else { throw LivecriptError.invalid("Format audio indisponible.") }
            try Task.checkCancellation()
            analyzer = instance; format = audioFormat; resourceMessage = "Prêt · hors connexion"
        } catch { resourceMessage = "Modèle indisponible · Réessayer"; throw error }
    }
    /// Decides whether an audio notification must pause the capture.
    /// Activating our own session re-evaluates the route (category change,
    /// override, wake…), which must not stop the transcription we just started.
    /// Only an interruption that began, a vanished input device, or a media
    /// server reset genuinely ends the capture.
    static nonisolated func interruptsCapture(for notification: Notification) -> Bool {
        switch notification.name {
        case AVAudioSession.interruptionNotification:
            let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            return raw == AVAudioSession.InterruptionType.began.rawValue
        case AVAudioSession.routeChangeNotification:
            guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return false }
            return reason == .oldDeviceUnavailable
        case AVAudioSession.mediaServicesWereResetNotification:
            return true
        default:
            return false
        }
    }
    func start(segmentID: UUID) async throws -> AsyncThrowingStream<SpeechEvent, Error> {
        guard let analyzer, let format else { throw LivecriptError.invalid("Préparez le modèle avant de démarrer.") }
        guard await AVAudioApplication.requestRecordPermission() else { throw LivecriptError.invalid("Autorisez le microphone dans les réglages de l’iPhone.") }
        try Task.checkCancellation()
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true)
        let output = AsyncThrowingStream<SpeechEvent, Error>.makeStream()
        events = output.continuation
        let input = AsyncStream<AnalyzerInput>.makeStream(bufferingPolicy: .bufferingOldest(128))
        inputs = input.continuation
        if let transcriber {
            results = Task {
                for try await result in transcriber.results {
                    output.continuation.yield(.transcript(.init(segmentID: segmentID, text: String(result.text.characters), isFinal: result.isFinal)))
                }
            }
        } else if let dictation {
            results = Task {
                for try await result in dictation.results {
                    output.continuation.yield(.transcript(.init(segmentID: segmentID, text: String(result.text.characters), isFinal: result.isFinal)))
                }
            }
        }
        do {
            try await analyzer.start(inputSequence: input.stream)
            let (sourceFormat, buffers) = try capture.start()
            feeding = Task.detached(priority: .userInitiated) {
                guard let converter = AVAudioConverter(from: sourceFormat, to: format) else { throw LivecriptError.invalid("Conversion audio impossible.") }
                var lastLevel = Date.distantPast
                do {
                    for try await buffer in buffers {
                        try Task.checkCancellation()
                        let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * format.sampleRate / sourceFormat.sampleRate)) + 32
                        guard let converted = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { continue }
                        var supplied = false; var error: NSError?
                        let status = converter.convert(to: converted, error: &error) { _, state in
                            if supplied { state.pointee = .noDataNow; return nil }
                            supplied = true; state.pointee = .haveData; return buffer
                        }
                        if let error { throw error }
                        guard status != .error else { throw LivecriptError.invalid("Erreur de conversion audio.") }
                        if converted.frameLength > 0 {
                            if case .dropped = input.continuation.yield(AnalyzerInput(buffer: converted)) { throw LivecriptError.invalid("La transcription ne suit plus le microphone. Reprenez.") }
                        }
                        if Date().timeIntervalSince(lastLevel) > 0.04, let samples = buffer.floatChannelData?[0] {
                            let count = Int(buffer.frameLength)
                            var sum: Float = 0
                            for i in 0..<count { sum += samples[i] * samples[i] }
                            let rms = sqrt(sum / Float(max(count, 1)))
                            output.continuation.yield(.level(min(1, max(0, (20 * log10(max(rms, 0.00001)) + 55) / 45))))
                            lastLevel = .now
                        }
                    }
                    input.continuation.finish()
                } catch { input.continuation.finish(); output.continuation.finish(throwing: error); throw error }
            }
            for name in [AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification, AVAudioSession.mediaServicesWereResetNotification] {
                notifications.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { note in
                    guard Self.interruptsCapture(for: note) else { return }
                    output.continuation.yield(.interrupted)
                })
            }
            return output.stream
        } catch { await cancel(); throw error }
    }
    func finish() async throws {
        capture.stop()
        do {
            try await feeding?.value
            inputs?.finish()
            try await analyzer?.finalizeAndFinishThroughEndOfInput()
            try await results?.value
            events?.finish(); cleanup()
        } catch { await cancel(); throw error }
    }
    func cancel() async {
        capture.stop(); feeding?.cancel(); inputs?.finish()
        await analyzer?.cancelAndFinishNow()
        results?.cancel(); events?.finish(); cleanup()
    }
    private func cleanup() {
        for token in notifications { NotificationCenter.default.removeObserver(token) }
        notifications = []; feeding = nil; results = nil; inputs = nil; events = nil
        analyzer = nil; transcriber = nil; dictation = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
