import Foundation

/// 每日挑战 DTO
/// 对应后端 GET /api/home/daily 返回结构
struct DailyChallengeDTO: Decodable, Encodable, Sendable, Equatable {
    let title: String
    let prompt: String           // 挑战的 prompt（核心内容）
    let date: String?            // 日期
    let imageUrl: String?        // 图片 URL
    let persona: String?         // 目标用户类型
    let payload: [String: AnyCodableValue]?  // 扩展数据

    // 🆕 兼容旧 UI：如果 UI 使用 description，提供计算属性
    var description: String {
        prompt
    }

    // 🆕 难度（如果后端没返回，给默认值）
    var difficulty: String {
        payload?["difficulty"]?.stringValue ?? "Medium"
    }
}

// MARK: - AnyCodableValue 用于解析动态 payload
enum AnyCodableValue: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(String.self) { self = .string(v) }
        else if let v = try? container.decode(Int.self) { self = .int(v) }
        else if let v = try? container.decode(Double.self) { self = .double(v) }
        else if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else if container.decodeNil() { self = .null }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }
}