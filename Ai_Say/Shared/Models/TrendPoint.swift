import Foundation

struct TrendPoint: Identifiable, Hashable, Sendable {
    let id = UUID()
    let label: String
    let value: Double? // nil 表示缺失点
}
