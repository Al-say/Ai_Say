import Foundation
import AVFoundation

@MainActor
final class AudioLevelMeter: ObservableObject {
    @Published private(set) var level: Double = 0 // 0...1

    private weak var recorder: AVAudioRecorder?
    private var timer: Timer?

    func bind(recorder: AVAudioRecorder?) {
        self.recorder = recorder
        self.recorder?.isMeteringEnabled = true
    }

    func start() {
        stop()

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard let r = self.recorder else { return }

            r.updateMeters()
            let peak = r.peakPower(forChannel: 0) // -160...0

            // 映射到 0...1，并做轻微下限避免完全静止
            let normalized = max(0.02, min(1.0, pow(10.0, Double(peak) / 20.0)))
            self.level = normalized
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        level = 0
    }
}