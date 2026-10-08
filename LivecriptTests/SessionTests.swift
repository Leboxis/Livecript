import Foundation
import Testing

@testable import Livecript

/// Polls until `condition` holds so tests observe settled state instead of racing
/// the session's asynchronous transitions.
@MainActor
private func waitUntil(timeout: Duration = .seconds(10), _ condition: () async throws -> Bool) async throws {
    let deadline = ContinuousClock.now + timeout
    while try await !condition() {
        if ContinuousClock.now > deadline { throw CancellationError() }
        try await Task.sleep(for: .milliseconds(10))
    }
}

/// Fake service whose preparation can be suspended, so cancellation while the
/// model is being prepared is testable without real hardware.
@MainActor
final class ControllableSpeech: SpeechService {
    var suspendsPrepare = false
    var finishError: (any Error)?
    /// When true, `finish()` never returns, mimicking a stalled audio pipeline.
    var neverFinishes = false
    /// Text the service emits as a final result when finishing, mimicking a
    /// transcriber that still holds a pending word.
    var yieldsTextOnFinish: String?
    private(set) var preparedConfigurations: [RecognitionConfiguration] = []
    private(set) var starts = 0
    private(set) var cancels = 0
    private(set) var segments: [UUID] = []
    private var continuation: AsyncThrowingStream<SpeechEvent, Error>.Continuation?
    private var currentSegment: UUID?

    var activeSegment: UUID {
        guard let currentSegment else { fatalError("No segment started") }
        return currentSegment
    }

    func prepare(_ configuration: RecognitionConfiguration) async throws {
        preparedConfigurations.append(configuration)
        // Task.sleep honours cancellation, mirroring the real service's checkpoints.
        if suspendsPrepare { try await Task.sleep(for: .seconds(60)) }
    }

    func start(segmentID: UUID) async throws -> AsyncThrowingStream<SpeechEvent, Error> {
        starts += 1
        currentSegment = segmentID
        segments.append(segmentID)
        let pair = AsyncThrowingStream<SpeechEvent, Error>.makeStream()
        continuation = pair.continuation
        return pair.stream
    }

    func finish() async throws {
        if neverFinishes { try await Task.sleep(for: .seconds(60)) }
        if let yieldsTextOnFinish { emitFinal(yieldsTextOnFinish) }
        continuation?.finish()
        if let finishError { throw finishError }
    }

    func cancel() async {
        cancels += 1
        continuation?.finish()
    }

    func emit(_ event: SpeechEvent) { continuation?.yield(event) }

    func emitFinal(_ text: String) {
        emit(.transcript(.init(segmentID: activeSegment, text: text, isFinal: true)))
    }
}

@MainActor
struct SessionTests {
    private static let configuration = RecognitionConfiguration(localeIdentifier: "fr-FR", mode: .standard, vocabulary: [])

    private func makeSession() throws -> (ControllableSpeech, TranscriptStore, TranscriptionSession) {
        let service = ControllableSpeech()
        let store = TranscriptStore(modelContainer: try StorageFactory.make(inMemory: true))
        return (service, store, TranscriptionSession(service: service, store: store))
    }

    @Test func pauseDrainsAndResumesSameDraft() async throws {
        let (service, store, session) = try makeSession()
        service.yieldsTextOnFinish = "Dernier mot."
        await session.start(configuration: Self.configuration); await session.pause()
        #expect(session.state == .paused)
        #expect(session.finalText == "Dernier mot.")
        await session.resume(); await session.finish()
        #expect(session.finalText == "Dernier mot. Dernier mot.")
        _ = try await session.save(); #expect(try await store.transcripts().count == 1)
    }

    @Test func doubleStartStartsOnce() async throws {
        let (service, _, session) = try makeSession()
        async let first: Void = session.start(configuration: Self.configuration)
        async let second: Void = session.start(configuration: Self.configuration)
        _ = await (first, second)
        #expect(service.starts == 1); await session.finish()
    }

    @Test("Annuler pendant la préparation n'ouvre jamais le microphone")
    func cancelDuringPrepareNeverStartsMicrophone() async throws {
        let (service, _, session) = try makeSession()
        service.suspendsPrepare = true

        async let starting: Void = session.start(configuration: Self.configuration)
        try await waitUntil { service.preparedConfigurations.count == 1 }

        await session.pause()
        await starting

        #expect(service.starts == 0)
        #expect(session.state == .paused)
        // Cancelling must not leave the session silently resuming.
        try await Task.sleep(for: .milliseconds(150))
        #expect(service.starts == 0)
    }

    @Test("Une interruption met en pause sans reprise automatique")
    func interruptionPausesWithoutAutoResume() async throws {
        let (service, _, session) = try makeSession()
        await session.start(configuration: Self.configuration)
        #expect(session.state == .recording)

        service.emit(.interrupted)
        try await waitUntil { session.state == .paused }

        #expect(service.starts == 1)
        #expect(session.state == .paused)
        try await Task.sleep(for: .milliseconds(150))
        #expect(service.starts == 1)
    }

    @Test("Un échec de finalisation signale l'erreur et garde le brouillon")
    func finishFailureKeepsDraft() async throws {
        let (service, store, session) = try makeSession()
        await session.start(configuration: Self.configuration)

        service.emitFinal("Texte finalisé.")
        try await waitUntil { (try await store.loadDraft())?.text == "Texte finalisé." }

        service.finishError = LivecriptError.invalid("Finalisation impossible.")
        await session.pause()

        #expect(session.state == .failed)
        #expect(session.errorMessage != nil)
        #expect(session.finalText == "Texte finalisé.")
        #expect(try await store.loadDraft()?.text == "Texte finalisé.")
    }

    @Test("La finalisation ne bloque jamais l'interface")
    func pauseFinalizationTimeoutKeepsText() async throws {
        let (service, store, session) = try makeSession()
        session.finalizationTimeout = .milliseconds(200)
        service.neverFinishes = true
        await session.start(configuration: Self.configuration)

        service.emitFinal("Texte capté.")
        try await waitUntil { (try await store.loadDraft())?.text == "Texte capté." }

        // pause() itself may stay suspended on the stalled pipeline; the UI
        // must still leave `.finalizing` with the text kept.
        Task { await session.pause() }
        try await waitUntil { session.state == .paused }

        #expect(session.finalText == "Texte capté.")
        #expect(session.errorMessage != nil)
    }

    @Test("Modifier les réglages n'altère pas la session en cours")
    func changedSettingsDoNotMutateActiveConfiguration() async throws {
        let (service, store, session) = try makeSession()
        await session.start(configuration: Self.configuration)

        service.emitFinal("Bonjour.")
        try await waitUntil { (try await store.loadDraft())?.text == "Bonjour." }
        await session.pause()

        // Settings changed after the session captured its configuration.
        let changed = RecognitionConfiguration(localeIdentifier: "en-US", mode: .customVocabulary, vocabulary: ["Livecript"])

        let draft = try await store.loadDraft()
        #expect(draft?.localeIdentifier == "fr-FR")
        #expect(draft?.mode == .standard)
        #expect(service.preparedConfigurations == [Self.configuration])

        // A new session cannot silently replace an existing draft.
        await session.start(configuration: changed)
        #expect(service.preparedConfigurations == [Self.configuration])
        #expect(session.state == .paused)

        // The changed configuration applies once the draft is explicitly discarded.
        try await session.discard()
        await session.start(configuration: changed)
        #expect(service.preparedConfigurations == [Self.configuration, changed])
    }
}