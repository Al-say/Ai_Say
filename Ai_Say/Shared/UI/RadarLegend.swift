import SwiftUI

struct RadarLegend: View {
    let dimensions: [RadarDimension]
    var maxValue: Double = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(dimensions) { dim in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        // 颜色指示点：高绿、低红
                        Circle()
                            .fill(colorForScore(dim.value))
                            .frame(width: 8, height: 8)

                        Text(dim.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(String(format: "%.0f", dim.value))
                            .font(.headline)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 4)

                    // 细进度条
                    ProgressView(value: clamp(dim.value, 0, maxValue), total: maxValue)
                        .tint(colorForScore(dim.value))
                        .scaleEffect(y: 0.5)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func colorForScore(_ score: Double) -> Color {
        switch score {
        case 85...: return .green
        case 70..<85: return .blue
        case 60..<70: return .orange
        default: return .red
        }
    }

    private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(v, lo), hi)
    }
}