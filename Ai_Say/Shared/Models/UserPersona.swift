import Foundation

enum UserPersona: String, CaseIterable, Sendable, Codable {
    case examPrep = "EXAM_PREP"
    case careerGrowth = "CAREER_GROWTH"
    case dailyLife = "DAILY_LIFE"

    var title: String {
        switch self {
        case .examPrep: return "备考模式"
        case .careerGrowth: return "职场模式"
        case .dailyLife: return "日常生活"
        }
    }
}