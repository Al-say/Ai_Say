import Foundation

enum AppConfig {
    /// 真机调试：这里改成 Mac 局域网 IP
    static let baseURL: String = "http://192.168.0.104:8082"

    /// 网络超时（需要时给 Alamofire Session）
    static let requestTimeout: TimeInterval = 30
}