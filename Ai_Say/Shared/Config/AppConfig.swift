import Foundation

enum AppConfig {
    /// 动态配置host，支持真机调试时改成局域网IP
    /// 真机测试使用 Mac 局域网 IP，模拟器使用 localhost
    static var host: String {
        #if targetEnvironment(simulator)
        return UserDefaults.standard.string(forKey: "api_host") ?? "localhost"
        #else
        // 真机：使用配置的服务器IP，无默认值以确保安全
        return UserDefaults.standard.string(forKey: "api_host") ?? "localhost"
        #endif
    }

    /// 统一BaseURL，所有前端请求都使用2581端口
    static var baseURL: String {
        "http://\(host):2581"
    }

    /// 网络超时（需要时给 Alamofire Session）
    static let requestTimeout: TimeInterval = 30
}