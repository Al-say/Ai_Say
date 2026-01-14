import SwiftUI

struct GrowthView: View {
    @State private var range: RangeType = .days7

    enum RangeType: String, CaseIterable, Identifiable {
        case days7 = "7天"
        case days30 = "30天"
        case all = "全部"
        var id: String { rawValue }
    }

    // Mock：后续替换为 SwiftData 查询结果
    private var dims: [RadarDimension] = [
        .init(key: "fluency", title: "Fluency", value: 82),
        .init(key: "completeness", title: "Completeness", value: 74),
        .init(key: "relevance", title: "Relevance", value: 88)
    ]

    private var trendScores: [Double] = [62, 66, 70, 69, 74, 78, 81]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 1) 本周摘要
                    summaryRow

                    // 2) 雷达图 + 图例（iPad 横向更好看）
                    HStack(alignment: .top, spacing: 16) {
                        card {
                            RadarChart(dimensions: dims)
                                .frame(height: 320)
                        }

                        card {
                            RadarLegend(dimensions: dims)
                        }
                        .frame(width: 320)
                    }

                    // 3) 趋势图（先做简单折线）
                    card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("趋势")
                                .font(.headline)
                            SimpleLineChart(values: trendScores)
                                .frame(height: 160)
                        }
                    }

                    // 4) 成长路线（Timeline）
                    card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("成长路线")
                                .font(.headline)

                            GrowthTimeline(steps: [
                                .init(title: "入门", subtitle: "能完成简单自我介绍", progress: 1.0),
                                .init(title: "基础", subtitle: "能描述日常与过去经历", progress: 0.7),
                                .init(title: "进阶", subtitle: "能表达观点并给出理由", progress: 0.35),
                                .init(title: "熟练", subtitle: "语速稳定，错误少", progress: 0.1)
                            ])
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120) // 给底部导航留空间
            }
            .navigationTitle("成长")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("", selection: $range) {
                        ForEach(RangeType.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }
            }
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 12) {
            metricCard(title: "本周练习", value: "6次")
            metricCard(title: "平均分", value: "78")
            metricCard(title: "连续天数", value: "3天")
        }
    }

    private func metricCard(title: String, value: String) -> some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.title2).bold().monospacedDigit()
            }
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground)) // M3 的 tonal 容器效果
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}