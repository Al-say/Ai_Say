import Foundation

// ✅ 请求模型：退出 MainActor 隔离，满足 Encodable & Sendable
nonisolated struct TextEvalReq: Encodable, Sendable {
    let prompt: String
    let userText: String
    let expectedKeywords: [String]?
    let referenceAnswer: String?
}

// ✅ Issue
nonisolated struct Issue: Decodable, Identifiable, Sendable {
    var id: String { "\(offset)-\(length)-\(message.hashValue)" }
    let offset: Int
    let length: Int
    let message: String
    let replacements: [String]?
}

// ✅ 响应模型：新增 audioUrl
nonisolated struct TextEvalResp: Decodable, Sendable {
    let recordId: Int64?

    let fluency: Double
    let completeness: Double
    let relevance: Double

    let grammarIssueCount: Int?
    let issues: [Issue]?
    let suggestions: [String]?
    let missingKeywords: [String]?

    let audioUrl: String?          // 🆕 后端新增
    let createdAt: String?
}