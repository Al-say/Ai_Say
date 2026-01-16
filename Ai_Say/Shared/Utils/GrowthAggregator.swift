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
        let recent = items
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(recentN)

        var flu: [Double] = []
        var comp: [Double] = []
        var rel: [Double] = []

        for it in recent {
            if let resp = decodeResp(from: it.aiResponse) {
                flu.append(clamp(resp.fluency))
                comp.append(clamp(resp.completeness))
                rel.append(clamp(resp.relevance))
            }
        }

        guard !flu.isEmpty else { return [] }

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

    // MARK: - Daily (7 days)

    static func buildDailyTrend(items: [Item], days: Int) -> [TrendPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -(days - 1), to: today)!

        var bucket: [Date: [Double]] = [:]
        for it in items {
            guard let s = it.score else { continue }
            let day = cal.startOfDay(for: it.timestamp)
            guard day >= start && day <= today else { continue }
            bucket[day, default: []].append(clamp(s))
        }

        var points: [TrendPoint] = []
        for offset in 0..<days {
            let d = cal.date(byAdding: .day, value: offset, to: start)!
            let label = d.formatted(.dateTime.month(.twoDigits).day(.twoDigits))
            if let arr = bucket[d], !arr.isEmpty {
                points.append(.init(label: label, value: average(arr)))
            } else {
                points.append(.init(label: label, value: nil))
            }
        }
        return points
    }

    // MARK: - Weekly (rolling bucket)

    static func buildWeeklyTrend(items: [Item], days: Int) -> [TrendPoint] {
        let cal = Calendar.current
        let end = Date()
        let start = cal.date(byAdding: .day, value: -days, to: end)!

        let totalWeeks = Int(ceil(Double(days) / 7.0))
        var buckets: [[Double]] = Array(repeating: [], count: totalWeeks)

        for it in items {
            guard let s = it.score else { continue }
            guard it.timestamp >= start && it.timestamp <= end else { continue }
            let deltaDays = cal.dateComponents([.day], from: start, to: it.timestamp).day ?? 0
            let idx = min(max(deltaDays / 7, 0), totalWeeks - 1)
            buckets[idx].append(clamp(s))
        }

        var points: [TrendPoint] = []
        for w in 0..<totalWeeks {
            let weekStart = cal.date(byAdding: .day, value: w * 7, to: start)!
            let label = "W\(w+1)"
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
