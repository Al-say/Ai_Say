import SwiftUI

struct SimpleLineChart: View {
    let points: [TrendPoint]

    var body: some View {
        Canvas { context, size in
            let values = points.compactMap { $0.value }
            guard values.count >= 2 else { return }

            let minV = (values.min() ?? 0)
            let maxV = (values.max() ?? 100)
            let span = max(maxV - minV, 1)

            let stepX = size.width / CGFloat(max(points.count - 1, 1))
            func y(_ v: Double) -> CGFloat {
                let t = (v - minV) / span
                return size.height * (1 - CGFloat(t))
            }

            var path = Path()
            var started = false

            for (idx, p) in points.enumerated() {
                guard let v = p.value else { continue }
                let x = CGFloat(idx) * stepX
                let pt = CGPoint(x: x, y: y(v))
                if !started {
                    path.move(to: pt)
                    started = true
                } else {
                    path.addLine(to: pt)
                }
            }

            context.stroke(path, with: .color(.accentColor), lineWidth: 2)

            for (idx, p) in points.enumerated() {
                guard let v = p.value else { continue }
                let x = CGFloat(idx) * stepX
                let pt = CGPoint(x: x, y: y(v))
                let dot = Path(ellipseIn: CGRect(x: pt.x - 2.5, y: pt.y - 2.5, width: 5, height: 5))
                context.fill(dot, with: .color(.accentColor))
            }
        }
        .frame(height: 160)
    }
}