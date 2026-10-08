import Foundation

enum SpeechEvent: Sendable { case transcript(TranscriptEvent), level(Float), interrupted }
@MainActor protocol SpeechService: AnyObject {
    func prepare(_ configuration: RecognitionConfiguration) async throws
    func start(segmentID: UUID) async throws -> AsyncThrowingStream<SpeechEvent, Error>
    func finish() async throws
    func cancel() async
}
