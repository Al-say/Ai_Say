import SwiftUI

struct WaveformView: View {
    let samples: [CGFloat]

    var body: some View {
        // 直接用 Canvas，避免 GeometryReader 触发额外布局 pass
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let count = max(samples.count, 1)
            let barW = w / CGFloat(count)

            for (i, s) in samples.enumerated() {
                let x = CGFloat(i) * barW
                let barH = max(2, s * h)
                let rect = CGRect(
                    x: x + barW * 0.2,
                    y: (h - barH) / 2,
                    width: barW * 0.6,
                    height: barH
                )
                context.fill(
                    Path(roundedRect: rect, cornerRadius: barW * 0.3),
                    with: .color(.primary.opacity(0.8))
                )
            }
        }
        .frame(height: 80)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityLabel("录音波形")
    }
}