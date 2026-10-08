import Foundation
import Testing
@testable import Livecript
@MainActor final class FakeSpeech: SpeechService {
    var starts = 0
    var configuration: RecognitionConfiguration?
    var continuation: AsyncThrowingStream<SpeechEvent, Error>.Continuation?
    var segment = UUID()
    func prepare(_ configuration: RecognitionConfiguration) async throws { self.configuration = configuration; await Task.yield(); try Task.checkCancellation() }
    func start(segmentID: UUID) async throws -> AsyncThrowingStream<SpeechEvent, Error> {
        starts += 1; segment = segmentID
        let pair = AsyncThrowingStream<SpeechEvent, Error>.makeStream(); continuation = pair.continuation; return pair.stream
    }
    func finish() async throws {
        continuation?.yield(.transcript(.init(segmentID: segment, text: "Dernier mot.", isFinal: true)))
        continuation?.finish()
    }
    func cancel() async { continuation?.finish() }
}
@MainActor struct SessionTests {
    @Test func pauseDrainsAndResumesSameDraft() async throws {
        let service = FakeSpeech(); let store = TranscriptStore(modelContainer: try StorageFactory.make(inMemory: true))
        let session = TranscriptionSession(service: service, store: store)
        let config = RecognitionConfiguration(localeIdentifier: "fr-FR", mode: .standard, vocabulary: [])
        await session.start(configuration: config); await session.pause()
        #expect(session.state == .paused)
        #expect(session.finalText == "Dernier mot.")
        await session.resume(); await session.finish()
        #expect(session.finalText == "Dernier mot. Dernier mot.")
        _ = try await session.save(); #expect(try await store.transcripts().count == 1)
    }
    @Test func doubleStartStartsOnce() async throws {
        let service = FakeSpeech(); let session = TranscriptionSession(service: service, store: TranscriptStore(modelContainer: try StorageFactory.make(inMemory: true)))
        let config = RecognitionConfiguration(localeIdentifier: "fr-FR", mode: .standard, vocabulary: [])
        async let first: Void = session.start(configuration: config)
        async let second: Void = session.start(configuration: config)
        _ = await (first, second)
        #expect(service.starts == 1); await session.finish()
    }
}
