import Foundation

enum AppConfig {
    /// 动态配置host，支持真机调试时改成局域网IP
    static var host: String {
        UserDefaults.standard.string(forKey: "api_host") ?? "localhost"
    }

    /// 统一BaseURL，所有前端请求都使用8082端口
    static var baseURL: String {
        "http://\(host):8082"
    }

    /// 网络超时（需要时给 Alamofire Session）
    static let requestTimeout: TimeInterval = 30
}