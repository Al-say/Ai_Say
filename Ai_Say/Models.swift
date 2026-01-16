import Foundation

// ✅ 请求模型：退出 MainActor 隔离，满足 Encodable & Sendable
// 对应后端：POST /api/eval/text?persona=XXX  Body: {deviceId, prompt, userText}
nonisolated struct TextEvalReq: Encodable, Sendable {
    let deviceId: String      // 🆕 设备标识（必填）
    let prompt: String
    let userText: String
    let expectedKeywords: [String]?
    let referenceAnswer: String?
    // ⚠️ persona 已改为 Query 参数，不再放 Body
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
    let overallScore: Double?  // 🆕 新增

    let grammarIssueCount: Int?
    let issues: [Issue]?
    let suggestions: [String]?
    let missingKeywords: [String]?

    let audioUrl: String?          // 🆕 后端新增
    let createdAt: String?
    let userText: String?          // 🆕 新增
}