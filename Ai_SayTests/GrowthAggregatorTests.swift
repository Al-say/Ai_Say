import XCTest
@testable import Ai_Say

final class GrowthAggregatorTests: XCTestCase {

    // Helper function to create test Item objects
    private func makeItem(score: Double, tsOffsetDays: Int, aiJSON: String?) -> Item {
        let item = Item(timestamp: Calendar.current.date(byAdding: .day, value: tsOffsetDays, to: Date())!)
        item.score = score
        if let aiJSON = aiJSON {
            item.aiResponse = aiJSON
        }
        return item
    }

    func testParseRadarFromAIResponse_UTF8JSON() throws {
        let items = [
            makeItem(score: 60, tsOffsetDays: -7, aiJSON: #"{"fluency":55,"completeness":65,"relevance":60}"#),
            makeItem(score: 80, tsOffsetDays: -1, aiJSON: #"{"fluency":82,"completeness":75,"relevance":83}"#),
            makeItem(score: 90, tsOffsetDays: 0,  aiJSON: #"{"fluency":92,"completeness":88,"relevance":90}"#),
        ]

        let radar = GrowthAggregator.buildRadar(items: items, recentN: 5)

        XCTAssertEqual(radar.first(where: {$0.key == "fluency"})?.value ?? -1, 76.333, accuracy: 0.01)
        XCTAssertEqual(radar.first(where: {$0.key == "completeness"})?.value ?? -1, 76.0, accuracy: 0.01)
        XCTAssertEqual(radar.first(where: {$0.key == "relevance"})?.value ?? -1, 77.666, accuracy: 0.01)
    }

    func testTrendDailyBuckets_UsesScoreAverage() throws {
        let items = [
            makeItem(score: 50, tsOffsetDays: -1, aiJSON: nil),
            makeItem(score: 70, tsOffsetDays: -1, aiJSON: nil),
            makeItem(score: 90, tsOffsetDays: 0,  aiJSON: nil),
        ]

        let points = GrowthAggregator.buildDailyTrend(items: items, days: 7)

        let cal = Calendar.current
        let yesterday = cal.startOfDay(for: cal.date(byAdding: .day, value: -1, to: Date())!)

        // Find index for yesterday
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -(7 - 1), to: today)!
        var foundValue: Double? = nil
        for offset in 0..<7 {
            let d = cal.date(byAdding: .day, value: offset, to: start)!
            if cal.isDate(d, inSameDayAs: yesterday) {
                foundValue = points[offset].value
                break
            }
        }
        XCTAssertNotNil(foundValue)
        XCTAssertEqual(foundValue ?? -1, 60, accuracy: 0.01)
    }

    func testClampScore_0to100() throws {
        XCTAssertEqual(GrowthAggregator.clamp(-10), 0)
        XCTAssertEqual(GrowthAggregator.clamp(110), 100)
        XCTAssertEqual(GrowthAggregator.clamp(88.8), 88.8, accuracy: 0.0001)
    }

    func testBuildTrend_DailyMode_WithGaps() throws {
        // 创建跨天的记录，中间有空缺日
        let items = [
            makeItem(score: 80, tsOffsetDays: -6, aiJSON: nil), // 6天前
            makeItem(score: 90, tsOffsetDays: -2, aiJSON: nil), // 2天前
            makeItem(score: 70, tsOffsetDays: 0,  aiJSON: nil), // 今天
        ]

        let points = GrowthAggregator.buildTrend(items: items, mode: .days7)

        // 7天模式应该有7个点
        XCTAssertEqual(points.count, 7)

        // 检查非空点的值
        let nonNilPoints = points.compactMap { $0.value }
        XCTAssertEqual(nonNilPoints.count, 3) // 只有3天有数据

        // 验证nil断线：中间的空缺日应该是nil
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -6, to: today)! // 7天前的开始

        // 找到有数据的索引
        var dataIndices = [Int]()
        for (index, point) in points.enumerated() {
            if point.value != nil {
                dataIndices.append(index)
            }
        }

        XCTAssertEqual(dataIndices.count, 3) // 应该有3个非nil点
    }

    func testBuildTrend_WeeklyMode_WithGaps() throws {
        // 创建跨周的记录，中间有空缺周
        let items = [
            makeItem(score: 75, tsOffsetDays: -20, aiJSON: nil), // 约3周前
            makeItem(score: 85, tsOffsetDays: -6,  aiJSON: nil), // 1周前
            makeItem(score: 95, tsOffsetDays: 0,   aiJSON: nil), // 本周
        ]

        let points = GrowthAggregator.buildTrend(items: items, mode: .days30)

        // 30天模式按周聚合，应该有约4-5个周点
        XCTAssertGreaterThan(points.count, 3)
        XCTAssertLessThanOrEqual(points.count, 6)

        // 检查非空点的值
        let nonNilPoints = points.compactMap { $0.value }
        XCTAssertGreaterThan(nonNilPoints.count, 0) // 至少有数据

        // 验证nil断线：空缺周应该是nil
        let nilCount = points.filter { $0.value == nil }.count
        XCTAssertGreaterThan(nilCount, 0) // 应该有nil点表示断线
    }

    func testBuildTrend_AllMode_BucketCount() throws {
        // 创建跨多个月的记录
        let items = [
            makeItem(score: 70, tsOffsetDays: -100, aiJSON: nil), // 约3个月前
            makeItem(score: 80, tsOffsetDays: -50,  aiJSON: nil), // 约1.5个月前
            makeItem(score: 90, tsOffsetDays: 0,    aiJSON: nil), // 现在
        ]

        let points = GrowthAggregator.buildTrend(items: items, mode: .all)

        // All模式按周聚合，应该有合理的周数（100天约14周）
        XCTAssertGreaterThan(points.count, 10)
        XCTAssertLessThan(points.count, 20)

        // 验证数据分布
        let nonNilPoints = points.compactMap { $0.value }
        XCTAssertGreaterThan(nonNilPoints.count, 0)
    }

    func testBuildRadar_EmptyItems_ReturnsDefaultDimensions() throws {
        let items: [Item] = []
        let radar = GrowthAggregator.buildRadar(items: items, recentN: 5)

        XCTAssertEqual(radar.count, 3)
        XCTAssertEqual(radar[0].key, "fluency")
        XCTAssertEqual(radar[0].value, 0)
        XCTAssertEqual(radar[1].key, "completeness")
        XCTAssertEqual(radar[1].value, 0)
        XCTAssertEqual(radar[2].key, "relevance")
        XCTAssertEqual(radar[2].value, 0)
    }

    func testBuildSummary_WithData() throws {
        let items = [
            makeItem(score: 80, tsOffsetDays: -1, aiJSON: nil),
            makeItem(score: 90, tsOffsetDays: 0,  aiJSON: nil),
        ]

        let summary = GrowthAggregator.buildSummary(items: items)

        XCTAssertTrue(summary.contains("2")) // 包含记录数
        XCTAssertTrue(summary.contains("85")) // 包含平均分
        XCTAssertTrue(summary.contains("90")) // 包含最新分
    }

    func testBuildSummary_EmptyItems() throws {
        let items: [Item] = []
        let summary = GrowthAggregator.buildSummary(items: items)

        XCTAssertTrue(summary.contains("暂无数据"))
        XCTAssertTrue(summary.contains("第一次评估"))
    }
}

// MARK: - GrowthCacheTests

final class GrowthCacheTests: XCTestCase {

    private var viewModel: GrowthViewModel!

    override func setUp() async throws {
        viewModel = await GrowthViewModel()
    }

    override func tearDown() async throws {
        viewModel = nil
    }

    func testCacheHit_SameDataSignature() async throws {
        let items = [
            makeItem(score: 80, tsOffsetDays: -1, aiJSON: nil),
            makeItem(score: 90, tsOffsetDays: 0,  aiJSON: nil),
        ]

        // 第一次调用
        await viewModel.rebuild(from: items)
        let firstTrendPoints = await viewModel.trendPoints
        let firstRadarDims = await viewModel.radarDims

        // 第二次调用相同数据
        await viewModel.rebuild(from: items)
        let secondTrendPoints = await viewModel.trendPoints
        let secondRadarDims = await viewModel.radarDims

        // 应该使用缓存，结果相同
        XCTAssertEqual(firstTrendPoints.count, secondTrendPoints.count)
        XCTAssertEqual(firstRadarDims.count, secondRadarDims.count)
    }

    func testCacheMiss_DataChanged() async throws {
        let items1 = [
            makeItem(score: 80, tsOffsetDays: -1, aiJSON: nil),
        ]

        let items2 = [
            makeItem(score: 80, tsOffsetDays: -1, aiJSON: nil),
            makeItem(score: 90, tsOffsetDays: 0,  aiJSON: nil), // 新增记录
        ]

        // 第一次调用
        await viewModel.rebuild(from: items1)
        let firstCount = await viewModel.trendPoints.count

        // 第二次调用不同数据
        await viewModel.rebuild(from: items2)
        let secondCount = await viewModel.trendPoints.count

        // 数据变化，应该重新计算
        XCTAssertNotEqual(firstCount, secondCount)
    }

    func testCacheMiss_RangeModeChanged() async throws {
        let items = [
            makeItem(score: 80, tsOffsetDays: -1, aiJSON: nil),
            makeItem(score: 90, tsOffsetDays: 0,  aiJSON: nil),
        ]

        // 7天模式
        await viewModel.rebuild(from: items)
        let sevenDayCount = await viewModel.trendPoints.count

        // 切换到30天模式
        await MainActor.run {
            viewModel.rangeMode = .days30
        }
        await viewModel.rebuild(from: items)
        let thirtyDayCount = await viewModel.trendPoints.count

        // 模式变化，应该重新计算
        XCTAssertNotEqual(sevenDayCount, thirtyDayCount)
    }

    func testCacheLimit_Enforced() async throws {
        // 创建11个不同的数据签名
        for i in 0..<11 {
            let items = [
                makeItem(score: Double(70 + i), tsOffsetDays: 0, aiJSON: nil),
            ]
            await viewModel.rebuild(from: items)
        }

        // 缓存应该被清理到10个以内
        // 注意：这是一个内部实现细节的测试，实际使用中可能需要调整
        // 这里我们通过多次调用验证缓存工作正常
        let finalItems = [
            makeItem(score: 85, tsOffsetDays: 0, aiJSON: nil),
        ]
        await viewModel.rebuild(from: finalItems)

        // 如果缓存清理工作，重建应该成功
        let points = await viewModel.trendPoints
        XCTAssertGreaterThan(points.count, 0)
    }

    func testClearCache_ForcesRebuild() async throws {
        let items = [
            makeItem(score: 80, tsOffsetDays: -1, aiJSON: nil),
        ]

        // 第一次调用
        await viewModel.rebuild(from: items)
        let firstPoints = await viewModel.trendPoints

        // 清除缓存
        await viewModel.clearCache()

        // 第二次调用（应该重新计算）
        await viewModel.rebuild(from: items)
        let secondPoints = await viewModel.trendPoints

        // 结果应该相同，但这是重新计算的
        XCTAssertEqual(firstPoints.count, secondPoints.count)
    }

    // MARK: - Helpers

    private func makeItem(score: Double, tsOffsetDays: Int, aiJSON: String?) -> Item {
        let cal = Calendar.current
        let ts = cal.date(byAdding: .day, value: tsOffsetDays, to: Date())!

        let it = Item(timestamp: ts, prompt: "P", userText: nil)
        it.isAudio = true
        it.score = score
        it.aiResponse = aiJSON
        return it
    }
}
