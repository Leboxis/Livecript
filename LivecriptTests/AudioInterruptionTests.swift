import AVFoundation
import Foundation
import Testing

@testable import Livecript

/// The audio notifications that must (and must not) interrupt a capture.
/// Pure logic, so it runs on simulator without any hardware.
@Suite("Interruptions audio")
struct AudioInterruptionTests {
    private func notification(_ name: Notification.Name, routeReason: AVAudioSession.RouteChangeReason? = nil, interruptionType: AVAudioSession.InterruptionType? = nil) -> Notification {
        var userInfo: [AnyHashable: Any] = [:]
        if let routeReason { userInfo[AVAudioSessionRouteChangeReasonKey] = routeReason.rawValue }
        if let interruptionType { userInfo[AVAudioSessionInterruptionTypeKey] = interruptionType.rawValue }
        return Notification(name: name, object: nil, userInfo: userInfo)
    }

    @Test("L'activation de notre session ne coupe pas la capture")
    func ownActivationRouteChangesDoNotInterrupt() {
        let harmless: [AVAudioSession.RouteChangeReason] = [
            .categoryChange, .override, .wakeFromSleep,
            .noSuitableRouteForCategory, .routeConfigurationChange,
            .newDeviceAvailable, .unknown,
        ]
        for reason in harmless {
            let note = notification(AVAudioSession.routeChangeNotification, routeReason: reason)
            #expect(!AppleSpeechService.interruptsCapture(for: note), "La raison \(reason) ne doit pas interrompre")
        }
    }

    @Test("Un microphone débranché interrompt la capture")
    func vanishingInputInterrupts() {
        let note = notification(AVAudioSession.routeChangeNotification, routeReason: .oldDeviceUnavailable)
        #expect(AppleSpeechService.interruptsCapture(for: note))
    }

    @Test("Seule une interruption qui commence met en pause")
    func onlyBeganInterruptionPauses() {
        let began = notification(AVAudioSession.interruptionNotification, interruptionType: .began)
        #expect(AppleSpeechService.interruptsCapture(for: began))

        let ended = notification(AVAudioSession.interruptionNotification, interruptionType: .ended)
        #expect(!AppleSpeechService.interruptsCapture(for: ended))
    }

    @Test("Un redémarrage des services media interrompt la capture")
    func mediaResetInterrupts() {
        let note = notification(AVAudioSession.mediaServicesWereResetNotification)
        #expect(AppleSpeechService.interruptsCapture(for: note))
    }
}