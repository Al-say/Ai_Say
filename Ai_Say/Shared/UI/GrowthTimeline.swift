import SwiftUI

struct GrowthStep: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let progress: Double // 0...1
}

struct GrowthTimeline: View {
    let steps: [GrowthStep]

    var body: some View {
        VStack(spacing: 14) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { idx, step in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(Color.primary.opacity(0.9))
                            .frame(width: 10, height: 10)
                        if idx != steps.count - 1 {
                            Rectangle()
                                .fill(Color.primary.opacity(0.2))
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 16)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(step.title).font(.headline)
                        Text(step.subtitle).font(.callout).foregroundStyle(.secondary)
                        ProgressView(value: step.progress, total: 1.0)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}