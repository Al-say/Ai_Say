import Foundation

enum ScoreUtils {
    /// 后端给三项 0~100：Sprint1 用平均分当总分
    static func overall(fluency: Double, completeness: Double, relevance: Double) -> Double {
        (fluency + completeness + relevance) / 3.0
    }
}