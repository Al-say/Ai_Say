import Foundation

enum Endpoints {
    static var host: String {
        // 真机调试：设置为电脑局域网IP，例如 192.168.0.104
        UserDefaults.standard.string(forKey: "api_host") ?? "192.168.0.104"
    }

    static var baseURL: String {
        "http://\(host):8082"
    }

    // 评估模块
    static let evalAudio     = "/api/eval/audio"
    static let evalAudioFull = "/api/eval/audio/full"  // 完整音频评估（推荐）
    static let evalText      = "/api/eval/text"

    // 成长模块
    static let growthHistory  = "/api/growth/history"
    static let growthAnalysis = "/api/growth/analysis"
    static let growthDetail   = "/api/growth/detail" // + "/{id}"

    // 首页模块
    static let homeDaily      = "/api/home/daily"     // ✅ 修正路径

    // 探索模块
    static let exploreScenes  = "/api/explore/scenes"

    // 个人中心模块
    static let profile        = "/api/profile"
    static let profileStats   = "/api/profile/stats"

    // 音频上传
    static let audioUpload    = "/api/audio/upload"

    static let uploadsPrefix  = "/uploads/"

    static func url(_ path: String) -> String {
        "\(baseURL)\(path)"
    }
}