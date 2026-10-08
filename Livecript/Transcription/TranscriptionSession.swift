import Foundation
import Observation

enum SessionState: Equatable { case ready, preparing, recording, paused, finalizing, failed }
@MainActor @Observable final class AudioMeter { var level: Float = 0 }
@MainActor @Observable final class TranscriptionSession {
    private(set) var state: SessionState = .ready
    private(set) var accumulator = TranscriptAccumulator()
    var errorMessage: String?
    var saved = false
    let meter = AudioMeter()
    var finalText: String { accumulator.finalText }
    var provisionalText: String { accumulator.provisionalText }
    var displayText: String { accumulator.displayText }
    var isBusy: Bool { state == .preparing || state == .finalizing }
    @ObservationIgnored private let service: any SpeechService
    @ObservationIgnored private let store: TranscriptStore
    @ObservationIgnored private var configuration: RecognitionConfiguration?
    @ObservationIgnored private var draftID = UUID()
    @ObservationIgnored private var preparingTask: Task<Void, Error>?
    @ObservationIgnored private var consuming: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var restored = false
    /// Maximum time finalization may keep the UI in `.finalizing`. If the audio
    /// pipeline stalls, the session is torn down and the captured text is kept
    /// instead of spinning forever. Shortened in tests.
    @ObservationIgnored var finalizationTimeout: Duration = .seconds(5)
    @ObservationIgnored private var finalizeSettled = false
    init(service: any SpeechService, store: TranscriptStore) { self.service = service; self.store = store }
    func restore() async {
        guard !restored else { return }; restored = true
        do {
            if let draft = try await store.loadDraft() {
                draftID = draft.id; accumulator = .init(text: draft.text)
                configuration = .init(localeIdentifier: draft.localeIdentifier, mode: draft.mode, vocabulary: try await store.vocabulary().map(\.phrase))
                state = .paused
            }
        } catch { errorMessage = "Impossible de récupérer le brouillon : \(error.localizedDescription)"; state = .failed }
    }
    func start(configuration: RecognitionConfiguration) async {
        guard state == .ready, finalText.isEmpty else { return }
        self.configuration = configuration; await beginSegment()
    }
    private func beginSegment() async {
        guard let configuration, state != .preparing, state != .recording, state != .finalizing else { return }
        state = .preparing; errorMessage = nil; saved = false
        let token = UUID(); generation = token
        let preparation = Task { try await service.prepare(configuration) }
        preparingTask = preparation
        do {
            try await preparation.value
            guard generation == token else { return }
            let segment = UUID(); accumulator.beginSegment(id: segment)
            let stream = try await service.start(segmentID: segment)
            guard generation == token else { await service.cancel(); return }
            state = .recording; preparingTask = nil
            consuming = Task { [weak self] in
                do {
                    for try await event in stream {
                        guard let self, generation == token else { break }
                        switch event {
                        case .transcript(let result):
                            accumulator.receive(result)
                            if result.isFinal { try await store.saveDraft(snapshot()) }
                        case .level(let value): meter.level = value
                        case .interrupted: Task { await self.pause() }
                        }
                    }
                } catch {
                    guard let self, generation == token else { return }
                    errorMessage = error.localizedDescription; state = .failed; meter.level = 0
                    await service.cancel()
                }
            }
        } catch {
            guard generation == token else { return }
            await service.cancel(); errorMessage = error.localizedDescription; state = .failed
        }
    }
    func pause() async {
        if state == .preparing {
            generation = UUID(); preparingTask?.cancel()
            await service.cancel(); state = .paused; return
        }
        guard state == .recording else { return }
        state = .finalizing
        let token = generation
        finalizeSettled = false
        let watchdog = Task { [weak self] in
            try? await Task.sleep(for: self?.finalizationTimeout ?? .seconds(5))
            await self?.abortFinalization(token: token)
        }
        do {
            try await service.finish(); await consuming?.value; consuming = nil
            finalizeSettled = true
            watchdog.cancel()
            guard generation == token else { return }
            meter.level = 0
            if state != .failed { try await store.saveDraft(snapshot()); state = .paused }
        } catch {
            watchdog.cancel()
            guard generation == token else { return }
            await service.cancel(); errorMessage = error.localizedDescription; state = .failed; meter.level = 0
        }
    }

    /// Last resort when finalization stalls: tear the pipeline down and hand the
    /// UI back with the text captured so far. The in-flight `pause()` is
    /// invalidated through `generation` so its late resumption changes nothing.
    private func abortFinalization(token: UUID) async {
        guard state == .finalizing, generation == token, !finalizeSettled else { return }
        generation = UUID()
        await service.cancel()
        consuming?.cancel(); consuming = nil
        meter.level = 0
        try? await store.saveDraft(snapshot())
        errorMessage = "La finalisation a pris trop de temps. Le texte affiché est conservé, vous pouvez reprendre."
        state = .paused
    }
    func resume() async { guard state == .paused || state == .failed else { return }; await beginSegment() }
    func finish() async {
        await pause()
        if state == .paused { state = .ready }
    }
    func save() async throws -> UUID {
        guard !isBusy, state != .recording else { throw LivecriptError.invalid("Terminez la transcription avant de l’enregistrer.") }
        let id = try await store.saveTranscript(snapshot()); saved = true; return id
    }
    func discard() async throws {
        guard !isBusy, state != .recording else { return }
        try await store.discardDraft()
        generation = UUID(); draftID = UUID(); accumulator = .init(); configuration = nil; state = .ready; saved = false; errorMessage = nil
    }
    private func snapshot() -> DraftSnapshot {
        .init(id: draftID, text: finalText, localeIdentifier: configuration?.localeIdentifier ?? "fr-FR", mode: configuration?.mode ?? .standard)
    }
}
