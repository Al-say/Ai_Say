import Foundation

/// 场景 DTO
struct SceneDTO: Decodable, Identifiable, Sendable, Equatable {
    let id: Int64
    let title: String
    let prompt: String
    let targetPersona: String? // "EXAM_PREP"/"CAREER_GROWTH"/null
}