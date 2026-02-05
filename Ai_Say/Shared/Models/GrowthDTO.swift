import Foundation

// MARK: - Growth API 响应模型

/// 历史记录项 (用于趋势图)
/// GET /api/growth/history
struct GrowthHistoryItem: Decodable, Identifiable, Sendable {
    let id: Int64
    let overallScore: Double?
    let fluency: Double?        // 🔧 可能为 null
    let completeness: Double?   // 🔧 可能为 null
    let relevance: Double?      // 🔧 可能为 null
    let createdAt: String
    let prompt: String?
    let userText: String?
    
    // 💡 辅助计算属性：为了 UI 显示方便，如果为空就返回 0
    var fluencyValue: Int { Int(fluency ?? 0) }
    var completenessValue: Int { Int(completeness ?? 0) }
    var relevanceValue: Int { Int(relevance ?? 0) }
    var overallValue: Int { Int(overallScore ?? 0) }
    
    /// 格式化日期 (yyyy-MM-dd)
    var date: String { String(createdAt.prefix(10)) }
}

/// 雷达图分析数据 (90天)
/// GET /api/growth/analysis
struct GrowthAnalysisDTO: Decodable, Sendable {
    let avgFluency: Double?       // 🔧 可能为 null (没有有效数据时)
    let avgCompleteness: Double?  // 🔧 可能为 null
    let avgRelevance: Double?     // 🔧 可能为 null
    let totalCount: Int?          // 🔧 可能为 null
    let periodDays: Int?          // 🔧 可能为 null
    
    // 💡 UI 显示用的兜底计算属性
    var fluency: Double { avgFluency ?? 0.0 }
    var completeness: Double { avgCompleteness ?? 0.0 }
    var relevance: Double { avgRelevance ?? 0.0 }
    var count: Int { totalCount ?? 0 }
    var days: Int { periodDays ?? 90 }
}

/// 单条评估详情
/// GET /api/growth/detail/{id}
struct GrowthDetailDTO: Decodable, Sendable {
    let id: Int64
    let prompt: String?
    let userText: String?
    let fluency: Double
    let completeness: Double
    let relevance: Double
    let overallScore: Double?
    let grammarIssueCount: Int?
    let issues: [Issue]?
    let suggestions: [String]?
    let audioUrl: String?
    let createdAt: String
}

/// 评估记录 DTO (用于历史记录)
/// GET /api/v1/evaluate/history
struct EvaluationRecordDTO: Decodable, Identifiable, Sendable {
    let id: String
    let taskId: String?
    let transcript: String?
    let persona: String?
    let scene: String?
    let status: String?
    let score: Double?
    let fluency: Double?
    let completeness: Double?
    let relevance: Double?
    let issues: [Issue]?
    let suggestions: [String]?
    let audioUrl: String?
    let createdAt: String?
    let completedAt: String?
}

/// 评估详情 DTO
/// GET /api/growth/{recordId}
struct EvaluationDetailDTO: Decodable, Sendable {
    let id: String
    let taskId: String?
    let transcript: String?
    let persona: String?
    let scene: String?
    let status: String?
    let score: Double?
    let fluency: Double?
    let completeness: Double?
    let relevance: Double?
    let issues: [Issue]?
    let suggestions: [String]?
    let audioUrl: String?
    let createdAt: String?
    let completedAt: String?
    let feedback: String?
}

/// 成长统计 DTO
/// GET /api/growth/stats
struct GrowthStatsDTO: Decodable, Sendable {
    let totalEvaluations: Int?
    let averageScore: Double?
    let totalPracticeTime: Int?  // 分钟
    let currentStreak: Int?
    let bestStreak: Int?
    let lastEvaluationDate: String?
    let improvementRate: Double?  // 百分比
    
    // 辅助属性
    var evaluations: Int { totalEvaluations ?? 0 }
    var score: Double { averageScore ?? 0.0 }
    var practiceTime: Int { totalPracticeTime ?? 0 }
    var streak: Int { currentStreak ?? 0 }
    var best: Int { bestStreak ?? 0 }
    var improvement: Double { improvementRate ?? 0.0 }
}

// MARK: - Profile API 响应模型

/// 用户统计数据
/// GET /api/profile/stats
struct ProfileStatsDTO: Decodable, Sendable {
    // 🔴 后端返回的是 CamelCase，需要显式 CodingKeys
    let totalAttempts: Int?          // 总练习次数
    let totalDurationMs: Int?        // 总时长（毫秒）
    let streakDays: Int?             // 连续天数
    let lastActiveDate: String?      // 最后活跃日期
    let deviceId: String?            // 设备 ID
    
    // 🔑 强制匹配后端 CamelCase 字段名
    enum CodingKeys: String, CodingKey {
        case totalAttempts = "totalAttempts"
        case totalDurationMs = "totalDurationMs"
        case streakDays = "streakDays"
        case lastActiveDate = "lastActiveDate"
        case deviceId = "deviceId"
    }
    
    // 💡 辅助属性：安全访问 + 单位转换
    var practiceCount: Int { totalAttempts ?? 0 }
    var streak: Int { streakDays ?? 0 }
    
    /// 毫秒转分钟
    var durationMinutes: Int {
        guard let ms = totalDurationMs else { return 0 }
        return ms / 1000 / 60
    }
    
    /// 格式化时长显示
    var durationDisplay: String {
        let mins = durationMinutes
        if mins >= 60 {
            return String(format: "%.1fh", Double(mins) / 60.0)
        }
        return "\(mins)m"
    }
}

/// 个人中心模块信息
/// GET /api/profile
struct ProfileDTO: Decodable, Sendable {
    let version: String?
    let features: [String]?
}
