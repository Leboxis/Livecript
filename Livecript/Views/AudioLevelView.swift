import SwiftUI
struct AudioLevelView: View {
    let meter: AudioMeter
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let weights: [CGFloat] = [0.3,0.5,0.8,0.6,1,0.7,0.9,0.5,0.8,0.4,0.6,1,0.7,0.4,0.2]
    var body: some View {
        HStack(spacing: 5) {
            ForEach(weights.indices, id: \.self) { index in
                Capsule().fill(active ? Color.accentColor : Color.secondary.opacity(0.4))
                    .frame(width: 4, height: 4 + weights[index] * CGFloat(meter.level) * 48)
            }
        }
        .frame(height: 56)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: meter.level)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(active ? "Microphone actif" : "Microphone arrêté")
    }
}
