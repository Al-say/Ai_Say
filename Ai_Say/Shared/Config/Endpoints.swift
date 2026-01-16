import Foundation

enum Endpoints {
    static var host: String {
        UserDefaults.standard.string(forKey: "api_host") ?? "localhost"
    }

    static var baseURL: String {
        "http://\(host):8082"
    }

    static let evalAudio = "/api/eval/audio"
    static let evalText  = "/api/eval/text"

    static let growthHistory  = "/api/growth/history"
    static let growthAnalysis = "/api/growth/analysis"
    static let growthDetail   = "/api/growth/detail" // + "/{id}"

    static let homeDashboard  = "/api/home/dashboard"
    static let exploreScenes  = "/api/explore/scenes"

    static let uploadsPrefix = "/uploads/"

    static func url(_ path: String) -> String {
        "\(baseURL)\(path)"
    }
}