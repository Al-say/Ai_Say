import Foundation
import Combine

@MainActor
final class GrowthViewModel: ObservableObject {

    enum RangeMode: String, CaseIterable, Identifiable {
        case days7 = "7天"
        case days30 = "30天"
        case all = "全部"
        var id: String { rawValue }
    }

    enum DataSource: String, CaseIterable, Identifiable {
        case local = "本地"
        case cloud = "云端"
        var id: String { rawValue }
    }

    // MARK: - Published Properties
    @Published var rangeMode: RangeMode = .days7
    @Published var dataSource: DataSource = .cloud  // 🆕 默认使用云端
    @Published private(set) var trendPoints: [TrendPoint] = []
    @Published private(set) var radarDims: [RadarDimension] = []
    @Published private(set) var summaryText: String = ""

    // 🆕 云端数据状态
    @Published private(set) var historyRecords: [GrowthHistoryItem] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    // MARK: - Private
    private let client = EvalAPIClient.shared
    private var cache: [String: (trendPoints: [TrendPoint], radarDims: [RadarDimension], summaryText: String)] = [:]

    // MARK: - 🆕 云端数据加载
    func loadFromCloud() async {
        let persona = PersonaStore.shared.current
        isLoading = true
        errorMessage = nil

        do {
            // 请求历史列表
            let history = try await client.fetchGrowthHistory(persona: persona, limit: 50)

            historyRecords = history

            // 🆕 从云端数据构建图表
            rebuildFromCloudData()

            NetworkLogger.log("Growth 云端数据加载成功: \(history.count) 条记录", type: .success)

        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
            NetworkLogger.log("Growth 云端加载失败: \(error)", type: .error)
        }

        isLoading = false
    }

    /// 从云端数据构建趋势图和雷达图
    private func rebuildFromCloudData() {
        // 构建趋势点
        trendPoints = historyRecords.prefix(20).enumerated().map { index, record in
            let score = record.overallScore ?? {
                let f = record.fluency ?? 0
                let c = record.completeness ?? 0
                let r = record.relevance ?? 0
                return (f + c + r) / 3
            }()
            return TrendPoint(
                label: formatDate(record.createdAt),
                value: score
            )
        }.reversed()

        // 构建雷达图维度 - 总是从历史记录计算
        if !historyRecords.isEmpty {
            // 从历史记录计算平均值
            let recent = Array(historyRecords.prefix(20)) // 使用更多记录计算平均值
            let avgFluency = recent.compactMap(\.fluency).reduce(0, +) / Double(max(recent.compactMap(\.fluency).count, 1))
            let avgCompleteness = recent.compactMap(\.completeness).reduce(0, +) / Double(max(recent.compactMap(\.completeness).count, 1))
            let avgRelevance = recent.compactMap(\.relevance).reduce(0, +) / Double(max(recent.compactMap(\.relevance).count, 1))

            radarDims = [
                RadarDimension(key: "fluency", title: "流利度", value: avgFluency),
                RadarDimension(key: "completeness", title: "完整度", value: avgCompleteness),
                RadarDimension(key: "relevance", title: "相关性", value: avgRelevance)
            ]
            summaryText = "共 \(historyRecords.count) 次练习"
        } else {
            radarDims = []
            summaryText = "暂无数据"
        }
    }

    private func formatDate(_ dateString: String) -> String {
        // 简单格式化：取日期部分
        if let range = dateString.range(of: "T") {
            return String(dateString[..<range.lowerBound].suffix(5)) // MM-DD
        }
        return String(dateString.suffix(5))
    }

    // MARK: - 本地数据支持 (保留兼容)
    func rebuild(from items: [Item]) {
        guard dataSource == .local else { return }

        let sortedItems = items.sorted { $0.timestamp > $1.timestamp }
        let latestTimestamp = sortedItems.first?.timestamp.timeIntervalSince1970 ?? 0
        let currentSignature = "\(latestTimestamp)-\(items.count)-\(rangeMode.rawValue)"

        if let cached = cache[currentSignature] {
            trendPoints = cached.trendPoints
            radarDims = cached.radarDims
            summaryText = cached.summaryText
            return
        }

        let filtered = filterItems(items)
        let newTrendPoints = GrowthAggregator.buildTrend(items: filtered, mode: rangeMode)
        let newRadarDims = GrowthAggregator.buildRadar(items: filtered, recentN: 5)
        let newSummaryText = GrowthAggregator.buildSummary(items: filtered)

        trendPoints = newTrendPoints
        radarDims = newRadarDims
        summaryText = newSummaryText

        cache[currentSignature] = (newTrendPoints, newRadarDims, newSummaryText)

        if cache.count > 10 {
            let keysToRemove = cache.keys.sorted().prefix(cache.count - 10)
            keysToRemove.forEach { cache.removeValue(forKey: $0) }
        }
    }

    private func filterItems(_ items: [Item]) -> [Item] {
        return items.filter { $0.score != nil }
    }

    func clearCache() {
        cache.removeAll()
    }
}
