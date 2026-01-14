import Foundation

enum AppError: LocalizedError, Equatable {
    case permissionDenied
    case recordingFailed(String)
    case networkFailed(String)
    case serverFailed(status: Int, message: String)
    case decodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "麦克风权限未授权：请到系统设置开启麦克风权限。"
        case .recordingFailed(let msg):
            return "录音失败：\(msg)"
        case .networkFailed(let msg):
            return "网络错误：\(msg)"
        case .serverFailed(let status, let message):
            return "服务器错误(\(status))：\(message)"
        case .decodeFailed(let msg):
            return "解析失败：\(msg)"
        }
    }
}