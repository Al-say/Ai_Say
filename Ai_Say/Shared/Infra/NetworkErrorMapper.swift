import Foundation

enum NetworkErrorMapper {
    static func server(status: Int, rawBody: String) -> AppError {
        let trimmed = String(rawBody.prefix(300))
        return .serverFailed(status: status, message: trimmed.isEmpty ? "<empty>" : trimmed)
    }

    static func decode(_ err: Error) -> AppError {
        .decodeFailed(err.localizedDescription)
    }
}