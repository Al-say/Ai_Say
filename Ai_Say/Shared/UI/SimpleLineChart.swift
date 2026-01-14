import SwiftUI

struct SimpleLineChart: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let maxV = (values.max() ?? 1)
            let minV = (values.min() ?? 0)
            let span = max(1e-6, maxV - minV)
            let stepX = w / CGFloat(max(values.count - 1, 1))

            Path { p in
                for (i, v) in values.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = h - CGFloat((v - minV) / span) * h
                    if i == 0 { p.move(to: .init(x: x, y: y)) }
                    else { p.addLine(to: .init(x: x, y: y)) }
                }
            }
            .stroke(.primary.opacity(0.8), lineWidth: 2)

            // 轻量"点"
            ForEach(Array(values.enumerated()), id: \.0) { i, v in
                let x = CGFloat(i) * stepX
                let y = h - CGFloat((v - minV) / span) * h
                Circle()
                    .fill(Color.primary)
                    .frame(width: 6, height: 6)
                    .position(x: x, y: y)
            }
        }
    }
}