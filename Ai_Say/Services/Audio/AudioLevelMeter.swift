import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioLevelMeter: ObservableObject {
    // 单值：给需要"音量条/呼吸感"的 UI 用
    @Published private(set) var level: Double = 0 // 0...1

    // ✅ 波形：给 Canvas 波形条用（你 RecordingView 里正在用 samples）
    @Published private(set) var samples: [CGFloat] = Array(repeating: 0.05, count: 24)

    private weak var recorder: AVAudioRecorder?
    private var timer: Timer?

    // 可调整参数
    private let sampleCount = 24
    private let minLevel: CGFloat = 0.05
    private let smoothing: CGFloat = 0.25

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

            // 归一化到 0...1
            let raw = min(1.0, max(self.minLevel, pow(10.0, Double(peak) / 20.0)))

            // 平滑：避免跳动过猛
            let newLevel = self.level + (raw - self.level) * self.smoothing
            self.level = newLevel

            // ✅ 推入波形采样：右进左出（或你需要左进右出也行）
            self.samples.append(CGFloat(newLevel))
            if self.samples.count > self.sampleCount {
                self.samples.removeFirst(self.samples.count - self.sampleCount)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        level = 0
        samples = Array(repeating: minLevel, count: sampleCount)
    }
}