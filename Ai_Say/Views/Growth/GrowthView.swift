import SwiftUI
import SwiftData

struct GrowthView: View {
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]
    @StateObject private var vm = GrowthViewModel()
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        NavigationStack {
            ScrollView {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        leftColumn
                            .frame(maxWidth: 540)
                        rightColumn
                            .frame(maxWidth: .infinity)
                    }
                    .padding(16)

                    VStack(spacing: 16) {
                        leftColumn
                        rightColumn
                    }
                    .padding(16)
                }
                .padding(.bottom, 120)
            }
            .navigationTitle("成长")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Debug Seed") {
                        Task { @MainActor in
                            seed3Items(context: context)
                        }
                    }
                }
            }
            .onAppear { vm.rebuild(from: items) }
            .onChange(of: items) { _, newValue in
                vm.rebuild(from: newValue)
            }
            .onChange(of: vm.rangeMode) { _, _ in
                vm.rebuild(from: items)
            }
        }
    }

    @MainActor
    private func seed3Items(context: ModelContext) {
        // 清理旧数据（只在测试环境用）
        let fetch = FetchDescriptor<Item>()
        if let existing = try? context.fetch(fetch) {
            existing.forEach { context.delete($0) }
        }

        let cal = Calendar.current
        let today = Date()
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: today)!

        func makeAIResponse(f: Double, c: Double, r: Double) -> String {
            """
            {"fluency":\(f),"completeness":\(c),"relevance":\(r),"issues":[],"suggestions":["Keep going"]}
            """
        }

        let a = Item(timestamp: sevenDaysAgo, prompt: "P1", userText: nil)
        a.isAudio = true
        a.score = 60
        a.aiResponse = makeAIResponse(f: 55, c: 65, r: 60)

        let b = Item(timestamp: yesterday, prompt: "P2", userText: nil)
        b.isAudio = true
        b.score = 80
        b.aiResponse = makeAIResponse(f: 82, c: 75, r: 83)

        let c = Item(timestamp: today, prompt: "P3", userText: nil)
        c.isAudio = true
        c.score = 90
        c.aiResponse = makeAIResponse(f: 92, c: 88, r: 90)

        context.insert(a)
        context.insert(b)
        context.insert(c)

        try? context.save()

        // 立即读取并触发 vm rebuild，打印结果
        let fetch2 = FetchDescriptor<Item>()
        if let fresh = try? context.fetch(fetch2) {
            vm.rebuild(from: fresh)

            // 打印 trendPoints
            print("DEBUG: trendPoints:")
            for p in vm.trendPoints {
                print("- \(p.label) : \(String(describing: p.value))")
            }

            // 打印 radar dimensions
            print("DEBUG: radarDimensions:")
            for d in vm.radarDims {
                print("- \(d.key) : \(d.value)")
            }
        }
    }

    private var leftColumn: some View {
        VStack(spacing: 16) {
            tonalCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("概览").font(.headline)
                    Text(vm.summaryText)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Picker("范围", selection: $vm.rangeMode) {
                        ForEach(GrowthViewModel.RangeMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            tonalCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("趋势").font(.headline)
                        Spacer()
                        Text(vm.rangeMode.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if vm.trendPoints.compactMap({ $0.value }).count < 2 {
                        emptyHint("练习次数不足，完成更多练习后解锁趋势图",
                                 actionText: "开始练习",
                                 action: { router.selectedTab = .home })
                    } else {
                        SimpleLineChart(points: vm.trendPoints)
                        axisLabels(vm.trendPoints)
                    }
                }
            }
        }
    }

    private var rightColumn: some View {
        VStack(spacing: 16) {
            tonalCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("能力雷达").font(.headline)

                    if vm.radarDims.isEmpty {
                        emptyHint("暂无可用维度数据，开始你的第一次评估吧！",
                                 actionText: "开始评估",
                                 action: { router.selectedTab = .home })
                    } else {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .top, spacing: 16) {
                                RadarChart(dimensions: vm.radarDims)
                                    .frame(width: 280, height: 280)
                                RadarLegend(dimensions: vm.radarDims)
                                    .frame(width: 260)
                            }
                            VStack(spacing: 12) {
                                RadarChart(dimensions: vm.radarDims)
                                    .frame(height: 280)
                                RadarLegend(dimensions: vm.radarDims)
                            }
                        }
                    }
                }
            }

            tonalCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("建议").font(.headline)
                    Text("基于最近练习的平均维度生成（前端聚合）。后续可接后端“成长洞察”接口返回更丰富文本。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func tonalCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func emptyHint(_ text: String, actionText: String? = nil, action: (() -> Void)? = nil) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundStyle(.secondary.opacity(0.5))

            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let actionText, let action {
                Button(action: action) {
                    Text(actionText)
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
        .padding(16)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func axisLabels(_ points: [TrendPoint]) -> some View {
        HStack {
            Text(points.first?.label ?? "")
            Spacer()
            Text(points.last?.label ?? "")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}