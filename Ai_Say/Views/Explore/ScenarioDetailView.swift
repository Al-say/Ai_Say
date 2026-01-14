import SwiftUI

struct ScenarioDetailView: View {
    let scenario: Scenario
    var onStart: ((Scenario) -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(scenario.title)
                        .font(.largeTitle.weight(.semibold))
                    Text(scenario.subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Text("难度：\(scenario.level.rawValue)")
                        Text("时长：\(scenario.minutes) 分钟")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(20)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                // Prompts
                VStack(alignment: .leading, spacing: 12) {
                    Text("练习题目")
                        .font(.headline)

                    ForEach(Array(scenario.prompts.enumerated()), id: \.offset) { idx, p in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(idx + 1)")
                                .font(.caption.weight(.bold))
                                .frame(width: 22, height: 22)
                                .background(Color.accentColor.opacity(0.12))
                                .clipShape(Circle())
                            Text(p)
                                .font(.body)
                        }
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }

                Button {
                    onStart?(scenario)
                } label: {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text("开始练习")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            .padding(20)
            .padding(.bottom, 120)
        }
        .navigationTitle("场景详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}