import Foundation

enum UserPersona: String, CaseIterable, Sendable, Codable {
    case examPrep = "EXAM_PREP"
    case careerGrowth = "CAREER_GROWTH"

    var title: String {
        switch self {
        case .examPrep: return "备考模式"
        case .careerGrowth: return "职场模式"
        }
    }
}