import Foundation

/// 网络请求日志工具
/// 用于联调阶段清晰展示请求和响应详情
enum NetworkLogger {

    // MARK: - 日志开关
    #if DEBUG
    static let isEnabled = true
    #else
    static let isEnabled = false
    #endif

    // MARK: - 请求日志
    static func logRequest(
        method: String,
        url: String,
        headers: [String: String]? = nil,
        body: Data? = nil,
        params: [String: Any]? = nil
    ) {
        guard isEnabled else { return }

        print("\n" + String(repeating: "─", count: 60))
        print("📤 REQUEST")
        print("├─ \(method) \(url)")

        if let params, !params.isEmpty {
            print("├─ Query: \(params)")
        }

        if let headers, !headers.isEmpty {
            print("├─ Headers: \(headers)")
        }

        if let body {
            if let json = try? JSONSerialization.jsonObject(with: body),
               let pretty = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let str = String(data: pretty, encoding: .utf8) {
                print("├─ Body (JSON):")
                str.split(separator: "\n").forEach { print("│  \($0)") }
            } else if let str = String(data: body, encoding: .utf8) {
                let preview = str.prefix(500)
                print("├─ Body: \(preview)\(str.count > 500 ? "... (\(str.count) bytes)" : "")")
            } else {
                print("├─ Body: <binary \(body.count) bytes>")
            }
        }

        print(String(repeating: "─", count: 60))
    }

    // MARK: - 响应日志
    static func logResponse(
        url: String,
        statusCode: Int,
        data: Data?,
        error: Error? = nil,
        duration: TimeInterval? = nil
    ) {
        guard isEnabled else { return }

        let statusEmoji = (200..<300).contains(statusCode) ? "✅" : "❌"
        let durationStr = duration.map { String(format: "%.2fs", $0) } ?? "-"

        print("\n" + String(repeating: "─", count: 60))
        print("📥 RESPONSE \(statusEmoji) [\(statusCode)] ⏱ \(durationStr)")
        print("├─ URL: \(url)")

        if let error {
            print("├─ ⚠️ Error: \(error.localizedDescription)")
        }

        if let data {
            if let json = try? JSONSerialization.jsonObject(with: data),
               let pretty = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let str = String(data: pretty, encoding: .utf8) {
                print("├─ Body (JSON):")
                let lines = str.split(separator: "\n")
                let maxLines = 30
                lines.prefix(maxLines).forEach { print("│  \($0)") }
                if lines.count > maxLines {
                    print("│  ... (\(lines.count - maxLines) more lines)")
                }
            } else if let str = String(data: data, encoding: .utf8) {
                let preview = str.prefix(1000)
                print("├─ Body: \(preview)\(str.count > 1000 ? "... (\(str.count) bytes)" : "")")
            } else {
                print("├─ Body: <binary \(data.count) bytes>")
            }
        }

        print(String(repeating: "─", count: 60) + "\n")
    }

    // MARK: - 解码错误日志
    static func logDecodeError(_ error: Error, rawData: Data?, context: String) {
        guard isEnabled else { return }

        print("\n" + String(repeating: "⚠", count: 30))
        print("🔴 DECODE ERROR: \(context)")
        print("├─ Error: \(error)")

        if let decodingError = error as? DecodingError {
            switch decodingError {
            case .keyNotFound(let key, let ctx):
                print("├─ Missing key: '\(key.stringValue)' at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))")
            case .typeMismatch(let type, let ctx):
                print("├─ Type mismatch: expected \(type) at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))")
            case .valueNotFound(let type, let ctx):
                print("├─ Value not found: \(type) at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))")
            case .dataCorrupted(let ctx):
                print("├─ Data corrupted at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))")
            @unknown default:
                print("├─ Unknown decoding error")
            }
        }

        if let data = rawData, let str = String(data: data, encoding: .utf8) {
            print("├─ Raw response preview:")
            print("│  \(str.prefix(500))")
        }

        print(String(repeating: "⚠", count: 30) + "\n")
    }

    // MARK: - 简易日志
    static func log(_ message: String, type: LogType = .info) {
        guard isEnabled else { return }
        print("\(type.emoji) [\(type.rawValue.uppercased())] \(message)")
    }

    enum LogType: String {
        case info, warning, error, success
        var emoji: String {
            switch self {
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .success: return "✅"
            }
        }
    }
}
