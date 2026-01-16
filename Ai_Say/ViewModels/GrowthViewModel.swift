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

    func rebuild(from items: [Item]) {
        let filtered = filterItems(items)
        trendPoints = GrowthAggregator.buildTrend(items: filtered, mode: rangeMode)
        radarDims = GrowthAggregator.buildRadar(items: filtered, recentN: 5)
        summaryText = GrowthAggregator.buildSummary(items: filtered)
    }

    private func filterItems(_ items: [Item]) -> [Item] {
        return items.filter { $0.score != nil }
    }
}
