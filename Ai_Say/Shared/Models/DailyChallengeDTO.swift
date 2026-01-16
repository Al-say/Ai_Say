import Foundation

/// 每日挑战 DTO
struct DailyChallengeDTO: Decodable, Encodable, Sendable, Equatable {
    let title: String
    let description: String
    let difficulty: String   // Easy/Medium/Hard（后端字符串）
    let prompt: String       // 挑战的 prompt
}