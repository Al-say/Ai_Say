import SwiftUI

struct RadarChart: View {
    let dimensions: [RadarDimension]
    var maxValue: Double = 100
    var gridCount: Int = 5
    var showLabels: Bool = true
    var showPoints: Bool = true

    @State private var scale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            Canvas { ctx, canvasSize in
                guard dimensions.count >= 3 else { return }

                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let baseRadius = min(canvasSize.width, canvasSize.height) * 0.36
                let radius = baseRadius * scale

                // 1) 网格（同心多边形）
                for i in 1...gridCount {
                    let r = radius * CGFloat(i) / CGFloat(gridCount)
                    let poly = polygonPath(center: center, radius: r, count: dimensions.count)
                    ctx.stroke(poly, with: .color(.gray.opacity(0.25)), lineWidth: 1)
                }

                // 2) 轴线
                for i in 0..<dimensions.count {
                    let angle = angleForIndex(i, count: dimensions.count)
                    let end = point(center: center, radius: radius, angle: angle)
                    var axis = Path()
                    axis.move(to: center)
                    axis.addLine(to: end)
                    ctx.stroke(axis, with: .color(.gray.opacity(0.25)), lineWidth: 1)
                }

                // 3) 标签
                if showLabels {
                    for i in 0..<dimensions.count {
                        let dim = dimensions[i]
                        let angle = angleForIndex(i, count: dimensions.count)
                        let labelPoint = point(center: center, radius: radius * 1.12, angle: angle)

                        let text = Text(dim.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ctx.draw(text, at: labelPoint, anchor: labelAnchor(for: angle))
                    }
                }

                // 4) 数据区域
                let values = dimensions.map { clamp($0.value, 0, maxValue) }
                let dataPoints = values.enumerated().map { (i, v) -> CGPoint in
                    let angle = angleForIndex(i, count: dimensions.count)
                    let r = radius * CGFloat(v / maxValue)
                    return point(center: center, radius: r, angle: angle)
                }

                var dataPath = Path()
                dataPath.addLines(dataPoints)
                dataPath.closeSubpath()

                // 使用 tint 作为主题色（由外层决定）
                ctx.fill(dataPath, with: .color(Color.accentColor.opacity(0.25)))
                ctx.stroke(dataPath, with: .color(Color.accentColor), lineWidth: 2)

                // 5) 数据点
                if showPoints {
                    for p in dataPoints {
                        let dot = Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6))
                        ctx.fill(dot, with: .color(Color.accentColor))
                    }
                }

                // 6) 中心圆（增强视觉锚点）
                let centerDot = Path(ellipseIn: CGRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4))
                ctx.fill(centerDot, with: .color(.gray.opacity(0.6)))
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .gesture(
                MagnificationGesture()
                    .onChanged { v in
                        // 限制缩放范围：0.8~1.6（iPad 适配）
                        scale = min(max(v, 0.8), 1.6)
                    }
            )
        }
        .frame(height: 320)
    }

    // MARK: - Geometry helpers

    private func angleForIndex(_ i: Int, count: Int) -> CGFloat {
        // 从顶部开始（-90°），顺时针
        (2 * .pi * CGFloat(i) / CGFloat(count)) - (.pi / 2)
    }

    private func point(center: CGPoint, radius: CGFloat, angle: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }

    private func polygonPath(center: CGPoint, radius: CGFloat, count: Int) -> Path {
        var p = Path()
        for i in 0..<count {
            let a = angleForIndex(i, count: count)
            let pt = point(center: center, radius: radius, angle: a)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(v, lo), hi)
    }

    private func labelAnchor(for angle: CGFloat) -> UnitPoint {
        // 简单按象限决定 anchor，避免标签压线
        let x = cos(angle)
        let y = sin(angle)

        switch (x, y) {
        case let (x, y) where x >= 0 && y < 0:  return .bottomLeading  // 右上
        case let (x, y) where x >= 0 && y >= 0: return .topLeading     // 右下
        case let (x, y) where x < 0 && y >= 0:  return .topTrailing    // 左下
        default:                                return .bottomTrailing // 左上
        }
    }
}