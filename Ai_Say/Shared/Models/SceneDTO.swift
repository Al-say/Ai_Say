import Foundation

/// 场景 DTO
/// GET /api/explore/scenes
struct SceneDTO: Decodable, Identifiable, Sendable, Equatable {
    let id: Int64
    let code: String?            // 🆕 场景代码 "biz_salary"
    let title: String
    let description: String?     // 场景描述
    let imageUrl: String?        // 场景图片 URL
    let category: String?        // 分类: DAILY_LIFE, IELTS, TOEFL, Business
    let targetPersona: String?   // "EXAM_PREP"/"CAREER_GROWTH"/null
    
    // 🔴 后端返回 initialPrompt，前端使用 prompt
    let prompt: String
    
    // 🟢 CodingKeys 映射后端字段名
    enum CodingKeys: String, CodingKey {
        case id
        case code
        case title
        case description
        case imageUrl
        case category
        case targetPersona
        case prompt = "initialPrompt"  // 🔴 关键：映射 initialPrompt -> prompt
    }
    
    // 💡 辅助属性
    var difficultyDisplay: String { "通用" } // 后端暂未返回 difficulty
}