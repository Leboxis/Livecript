import AVFoundation
import Foundation

/// The audio tap owns no UI state. Buffers are copied before leaving the callback.
final class MicrophoneCapture: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var continuation: AsyncThrowingStream<AVAudioPCMBuffer, Error>.Continuation?
    private var installed = false
    func start() throws -> (AVAudioFormat, AsyncThrowingStream<AVAudioPCMBuffer, Error>) {
        let node = engine.inputNode
        let format = node.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw LivecriptError.invalid("Aucun microphone disponible.") }
        let pair = AsyncThrowingStream<AVAudioPCMBuffer, Error>.makeStream(bufferingPolicy: .bufferingOldest(64))
        continuation = pair.continuation
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else { return }
            copy.frameLength = buffer.frameLength
            let source = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: buffer.audioBufferList))
            let target = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
            for (a, b) in zip(source, target) {
                if let src = a.mData, let dst = b.mData { memcpy(dst, src, Int(a.mDataByteSize)) }
            }
            if case .dropped = pair.continuation.yield(copy) { pair.continuation.finish(throwing: LivecriptError.invalid("Le traitement audio est trop lent. Reprenez la transcription.")) }
        }
        installed = true
        do { engine.prepare(); try engine.start() } catch { stop(); throw error }
        return (format, pair.stream)
    }
    func stop() {
        engine.stop()
        if installed { engine.inputNode.removeTap(onBus: 0); installed = false }
        continuation?.finish(); continuation = nil
    }
}
