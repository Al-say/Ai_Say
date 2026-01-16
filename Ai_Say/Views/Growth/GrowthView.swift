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
                // 🆕 加载状态
                if vm.isLoading {
                    ProgressView("正在从云端加载...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let error = vm.errorMessage {
                    errorView(error)
                } else {
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
                }
                
                // 🆕 历史记录列表 (云端数据)
                if !vm.historyRecords.isEmpty {
                    historySection
                        .padding(.horizontal, 16)
                }
                
                Spacer().frame(height: 120)
            }
            .navigationTitle("成长")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // 🆕 数据源切换
                    Menu {
                        Button("刷新云端") {
                            Task { await vm.loadFromCloud() }
                        }
                        Divider()
                        Picker("数据源", selection: $vm.dataSource) {
                            ForEach(GrowthViewModel.DataSource.allCases) { source in
                                Text(source.rawValue).tag(source)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
            }
            .refreshable {
                // 🆕 下拉刷新
                await vm.loadFromCloud()
            }
            .task {
                // 🆕 页面加载时自动拉取云端数据
                if vm.dataSource == .cloud {
                    await vm.loadFromCloud()
                }
            }
            .onChange(of: vm.dataSource) { _, newValue in
                if newValue == .local {
                    vm.rebuild(from: items)
                } else {
                    Task { await vm.loadFromCloud() }
                }
            }
            .onChange(of: items) { _, newValue in
                if vm.dataSource == .local {
                    vm.rebuild(from: newValue)
                }
            }
            .onChange(of: vm.rangeMode) { _, _ in
                if vm.dataSource == .local {
                    vm.rebuild(from: items)
                }
            }
        }
    }
    
    // 🆕 错误视图
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("重试") {
                Task { await vm.loadFromCloud() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
    }
    
    // 🆕 历史记录列表
    private var historySection: some View {
        tonalCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("练习记录").font(.headline)
                    Spacer()
                    Text("\(vm.historyRecords.count) 条")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                ForEach(vm.historyRecords.prefix(10)) { record in
                    historyRow(record)
                    if record.id != vm.historyRecords.prefix(10).last?.id {
                        Divider()
                    }
                }
            }
        }
    }
    
    private func historyRow(_ record: GrowthHistoryItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // 优先显示 prompt，否则显示日期 + ID
                Text(record.prompt ?? "练习 #\(record.id)")
                    .font(.subheadline)
                    .lineLimit(1)
                Text(formatDate(record.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(record.overallScore ?? 0))")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(scoreColor(record.overallScore ?? 0))
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ dateString: String) -> String {
        if let range = dateString.range(of: "T") {
            return String(dateString[..<range.lowerBound])
        }
        return dateString
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .orange }
        return .red
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
            Image(systemName: "chart.bar")
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