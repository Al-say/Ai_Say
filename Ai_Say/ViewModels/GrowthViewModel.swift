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

    @Published var rangeMode: RangeMode = .days7
    @Published private(set) var trendPoints: [TrendPoint] = []
    @Published private(set) var radarDims: [RadarDimension] = []
    @Published private(set) var summaryText: String = ""

    // 🎯 性能优化：添加缓存，避免重复计算
    private var cache: [String: (trendPoints: [TrendPoint], radarDims: [RadarDimension], summaryText: String)] = [:]
    private var lastItemsSignature: String = ""

    /// 智能重建：只有在数据真正变化时才重新计算
    /// - Parameter items: 新的Item数组
    func rebuild(from items: [Item]) {
        // 生成数据签名：包含最新时间戳和数量
        let sortedItems = items.sorted { $0.timestamp > $1.timestamp }
        let latestTimestamp = sortedItems.first?.timestamp.timeIntervalSince1970 ?? 0
        let currentSignature = "\(latestTimestamp)-\(items.count)-\(rangeMode.rawValue)"

        // 如果数据没变化，使用缓存
        if let cached = cache[currentSignature] {
            trendPoints = cached.trendPoints
            radarDims = cached.radarDims
            summaryText = cached.summaryText
            return
        }

        // 数据有变化，重新计算
        let filtered = filterItems(items)
        let newTrendPoints = GrowthAggregator.buildTrend(items: filtered, mode: rangeMode)
        let newRadarDims = GrowthAggregator.buildRadar(items: filtered, recentN: 5)
        let newSummaryText = GrowthAggregator.buildSummary(items: filtered)

        // 更新状态
        trendPoints = newTrendPoints
        radarDims = newRadarDims
        summaryText = newSummaryText

        // 更新缓存
        cache[currentSignature] = (newTrendPoints, newRadarDims, newSummaryText)

        // 清理旧缓存（保持最近10个）
        if cache.count > 10 {
            let keysToRemove = cache.keys.sorted().prefix(cache.count - 10)
            keysToRemove.forEach { cache.removeValue(forKey: $0) }
        }
    }

    /// 过滤有效数据项
    private func filterItems(_ items: [Item]) -> [Item] {
        return items.filter { $0.score != nil }
    }

    /// 清除缓存（用于调试或强制刷新）
    func clearCache() {
        cache.removeAll()
        lastItemsSignature = ""
    }
}
