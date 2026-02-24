import Foundation

enum AppConfig {
    /// 动态配置host，支持真机调试时改成局域网IP
    /// 真机测试使用 Mac 局域网 IP，模拟器使用 localhost
    static var host: String {
        #if targetEnvironment(simulator)
        return UserDefaults.standard.string(forKey: "api_host") ?? "localhost"
        #else
        // 真机：使用Mac的局域网IP
        return UserDefaults.standard.string(forKey: "api_host") ?? "192.168.0.106"
        #endif
    }

    /// 允许手动覆盖baseURL（用于真机调试）
    static var customBaseURL: String? {
        get { UserDefaults.standard.string(forKey: "custom_base_url") }
        set { UserDefaults.standard.set(newValue, forKey: "custom_base_url") }
    }

    /// 统一BaseURL，所有前端请求都使用2580端口
    /// 可以直接设置以覆盖默认值
    static var baseURL: String {
        get { customBaseURL ?? "http://\(host):2580" }
        set { customBaseURL = newValue }
    }

    /// 网络超时（需要时给 Alamofire Session）
    static let requestTimeout: TimeInterval = 30
}