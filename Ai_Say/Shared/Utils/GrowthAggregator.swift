import Foundation

enum GrowthAggregator {

    static func buildTrend(items: [Item], mode: GrowthViewModel.RangeMode) -> [TrendPoint] {
        switch mode {
        case .days7:
            return buildDailyTrend(items: items, days: 7)
        case .days30:
            return buildWeeklyTrend(items: items, days: 30)
        case .all:
            return buildWeeklyTrend(items: items, days: 180)
        }
    }

    static func buildRadar(items: [Item], recentN: Int) -> [RadarDimension] {
        // 🎯 统一口径2：预过滤 + 预排序（只排序一次）
        let validItems = items
            .filter { $0.score != nil }  // 先过滤有score的
            .sorted { $0.timestamp > $1.timestamp }  // 时间戳降序排序

        // 取最近N条数据
        let recent = validItems.prefix(recentN)

        var flu: [Double] = []
        var comp: [Double] = []
        var rel: [Double] = []

        // 🎯 得分口径：雷达图从aiResponse解出三维分
        for it in recent {
            if let resp = decodeResp(from: it.aiResponse) {
                flu.append(clamp(resp.fluency))
                comp.append(clamp(resp.completeness))
                rel.append(clamp(resp.relevance))
            }
        }

        // 🎯 数据不足时的处理：返回默认维度（值为0）
        guard !flu.isEmpty else {
            return [
                RadarDimension(key: "fluency", title: "流利度", value: 0),
                RadarDimension(key: "completeness", title: "完整度", value: 0),
                RadarDimension(key: "relevance", title: "相关性", value: 0)
            ]
        }

        // 🎯 可用维度平均：每个维度用其可用值的平均值
        return [
            RadarDimension(key: "fluency", title: "流利度", value: average(flu)),
            RadarDimension(key: "completeness", title: "完整度", value: average(comp)),
            RadarDimension(key: "relevance", title: "相关性", value: average(rel)),
        ]
    }

    static func buildSummary(items: [Item]) -> String {
        guard let last = items.sorted(by: { $0.timestamp > $1.timestamp }).first,
              let score = last.score else {
            return "完成第一次练习后解锁成长报告"
        }
        let s = Int(clamp(score).rounded())
        return "最近一次：\(s) 分 · \(last.timestamp.formatted(date: .abbreviated, time: .omitted))"
    }

    // MARK: - Daily (7 days) - 优化版：统一口径 + 性能优化

    static func buildDailyTrend(items: [Item], days: Int) -> [TrendPoint] {
        // 🎯 统一口径1：分桶基准 - 按用户本地日历
        let cal = Calendar.current

        // 🎯 统一口径2：预过滤 + 预排序（只排序一次）
        let validItems = items
            .filter { $0.score != nil }  // 先过滤有score的
            .sorted { $0.timestamp > $1.timestamp }  // 时间戳降序排序

        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -(days - 1), to: today)!

        // 🎯 性能优化：预分配bucket大小
        var bucket: [Date: [Double]] = Dictionary(minimumCapacity: days)

        // 遍历有效数据，生成bucket
        for it in validItems {
            let score = it.score!  // 已过滤，确保非nil
            let day = cal.startOfDay(for: it.timestamp)  // 🎯 生成bucket key

            // 只处理时间范围内的数据
            guard day >= start && day <= today else { continue }

            bucket[day, default: []].append(clamp(score))
        }

        // 生成固定数量的点（7天模式生成7个点）
        var points: [TrendPoint] = []
        points.reserveCapacity(days)  // 预分配容量

        for offset in 0..<days {
            let d = cal.date(byAdding: .day, value: offset, to: start)!
            let label = d.formatted(.dateTime.month(.twoDigits).day(.twoDigits))

            // 🎯 统一口径3：趋势线空洞策略 - 缺失日用nil（折线断开）
            if let arr = bucket[d], !arr.isEmpty {
                points.append(.init(label: label, value: average(arr)))
            } else {
                points.append(.init(label: label, value: nil))  // 断开折线
            }
        }
        return points
    }

    // MARK: - Weekly (rolling bucket) - 优化版：统一口径 + 性能优化

    static func buildWeeklyTrend(items: [Item], days: Int) -> [TrendPoint] {
        // 🎯 统一口径1：分桶基准 - 按用户本地日历
        let cal = Calendar.current

        // 🎯 统一口径2：预过滤 + 预排序（只排序一次）
        let validItems = items
            .filter { $0.score != nil }  // 先过滤有score的
            .sorted { $0.timestamp > $1.timestamp }  // 时间戳降序排序

        let end = Date()
        let start = cal.date(byAdding: .day, value: -days, to: end)!

        let totalWeeks = Int(ceil(Double(days) / 7.0))
        var buckets: [[Double]] = Array(repeating: [], count: totalWeeks)

        // 遍历有效数据，分配到周bucket
        for it in validItems {
            let score = it.score!  // 已过滤，确保非nil
            guard it.timestamp >= start && it.timestamp <= end else { continue }

            let deltaDays = cal.dateComponents([.day], from: start, to: it.timestamp).day ?? 0
            let idx = min(max(deltaDays / 7, 0), totalWeeks - 1)
            buckets[idx].append(clamp(score))
        }

        // 生成周趋势点
        var points: [TrendPoint] = []
        points.reserveCapacity(totalWeeks)  // 预分配容量

        for w in 0..<totalWeeks {
            let weekStart = cal.date(byAdding: .day, value: w * 7, to: start)!
            let label = "W\(w+1)"

            // 🎯 统一口径3：趋势线空洞策略 - 缺失周用nil（折线断开）
            let v = buckets[w].isEmpty ? nil : average(buckets[w])
            points.append(.init(label: label, value: v))
        }
        return points
    }

    // MARK: - Decode

    private struct TextEvalRespLite: Decodable {
        let fluency: Double
        let completeness: Double
        let relevance: Double
    }

    private static func decodeResp(from raw: String?) -> TextEvalRespLite? {
        guard let raw, let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(TextEvalRespLite.self, from: data)
    }

    // MARK: - Math

    private static func average(_ arr: [Double]) -> Double {
        guard !arr.isEmpty else { return 0 }
        return arr.reduce(0, +) / Double(arr.count)
    }

    static func clamp(_ v: Double) -> Double {
        min(max(v, 0), 100)
    }
}
