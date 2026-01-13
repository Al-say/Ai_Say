import Foundation

// 请求体 (对应 Java: EvalDTO.TextEvalReq)
struct TextEvalReq: Sendable {
    let prompt: String
    let userText: String
    let expectedKeywords: [String]?
    let referenceAnswer: String?
}

nonisolated extension TextEvalReq: Encodable {}

// 响应体 (对应 Java: EvalDTO.TextEvalResp)
struct TextEvalResp: Sendable {
    let recordId: Int64?

    let fluency: Double
    let completeness: Double
    let relevance: Double

    let grammarIssueCount: Int?
    let issues: [Issue]?

    let suggestions: [String]?
    let missingKeywords: [String]?

    let createdAt: String?
}

nonisolated extension TextEvalResp: Decodable {}

// 问题详情 (对应 Java: EvalDTO.Issue)
struct Issue: Identifiable, Sendable {
    var id: String { "\(offset)-\(length)-\(message)" }

    let offset: Int
    let length: Int
    let message: String
    let replacements: [String]?
}

nonisolated extension Issue: Decodable {}