import XCTest
@testable import Ai_Say

final class GrowthAggregatorTests: XCTestCase {

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
