import Foundation

/// 雷达图维度（可扩展到 4~6 个维度）
/// 目前 MVP：fluency / completeness / relevance（0~100）
struct RadarDimension: Identifiable, Hashable, Sendable {
    let id = UUID()
    let key: String          // 英文 key（用于内部映射/调试）
    let title: String        // UI 显示标题（中文）
    let value: Double        // 当前值
}

/// 将后端 TextEvalResp 转为雷达图维度数组
enum RadarMapper {
    static func from(resp: TextEvalResp) -> [RadarDimension] {
        [
            .init(key: "fluency", title: "流利度", value: resp.fluency),
            .init(key: "completeness", title: "完整度", value: resp.completeness),
            .init(key: "relevance", title: "相关性", value: resp.relevance)
        ]
    }
}