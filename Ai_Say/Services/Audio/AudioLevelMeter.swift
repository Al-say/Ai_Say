import Foundation
import AVFoundation
import SwiftUI
import Combine

@MainActor
final class AudioLevelMeter: ObservableObject {
    @Published var level: CGFloat = 0           // 0...1
    @Published var samples: [CGFloat] = Array(repeating: 0.05, count: 32)

    private var timer: Timer?
    private weak var recorder: AVAudioRecorder?

    func start(recorder: AVAudioRecorder) {
        self.recorder = recorder
        stop()

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let r = self.recorder, r.isRecording else { return }
                r.updateMeters()

                // averagePower: -160...0
                let avg = r.averagePower(forChannel: 0)
                let normalized = self.normalizePower(avg) // 0...1

                self.level = normalized
                self.pushSample(normalized)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func pushSample(_ v: CGFloat) {
        samples.removeFirst()
        samples.append(max(0.02, v))
    }

    private func normalizePower(_ power: Float) -> CGFloat {
        // 把 [-60, 0] 映射到 [0,1]，低于 -60 认为 0
        let p = max(-60, min(0, power))
        return CGFloat((p + 60) / 60)
    }
}