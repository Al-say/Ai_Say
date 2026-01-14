import Foundation

enum Endpoints {
    static let evalText = "/api/eval/text"
    static let evalAudio = "/api/eval/audio"
    static let uploadsPrefix = "/uploads/"

    static func url(_ path: String) -> String {
        "\(AppConfig.baseURL)\(path)"
    }
}