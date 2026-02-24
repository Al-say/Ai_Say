import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioLevelMeter: ObservableObject {
    // 单值：给需要"音量条/呼吸感"的 UI 用
    private(set) var level: Double = 0 // 0...1

    // ✅ 波形：给 Canvas 波形条用（你 RecordingView 里正在用 samples）
    // 使用固定大小循环缓冲区，避免 append+removeFirst O(n) 拷贝
    private(set) var samples: [CGFloat]

    private weak var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var writeIndex: Int = 0

    // 可调整参数
    private let sampleCount = 24
    private let minLevel: CGFloat = 0.05
    private let smoothing: Double = 0.25
    // 降至 15fps：对波形视觉感知足够，减少主线程压力
    private let timerInterval: TimeInterval = 1.0 / 15.0

    init() {
        samples = Array(repeating: 0.05, count: 24)
    }

    func bind(recorder: AVAudioRecorder?) {
        self.recorder = recorder
        self.recorder?.isMeteringEnabled = true
    }

    func start() {
        stop()

        timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard let r = self.recorder else { return }

            // ⚡️ 在 Timer 回调（已在 main RunLoop）直接计算，避免额外 dispatch 开销
            r.updateMeters()
            let peak = r.peakPower(forChannel: 0) // -160...0

            // 归一化到 0...1
            let raw = min(1.0, max(Double(self.minLevel), pow(10.0, Double(peak) / 20.0)))

            // 平滑
            let newLevel = self.level + (raw - self.level) * self.smoothing

            // ✅ 循环写入：O(1) 替换，无拷贝
            self.samples[self.writeIndex] = CGFloat(newLevel)
            self.writeIndex = (self.writeIndex + 1) % self.sampleCount

            // 合并 level + samples 为一次 UI 更新，避免触发两次 SwiftUI diff
            self.objectWillChange.send()
            self.level = newLevel
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        objectWillChange.send()
        level = 0
        writeIndex = 0
        samples = Array(repeating: Double(minLevel), count: sampleCount)
    }

    /// 按时间顺序取出样本（从最旧到最新）
    var orderedSamples: [CGFloat] {
        let tail = Array(samples[writeIndex...])
        let head = Array(samples[..<writeIndex])
        return tail + head
    }
}