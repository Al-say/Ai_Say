import UIKit

/// 设备标识管理器
/// 用于获取统一的设备 ID，供所有 API 请求使用
struct DeviceIdManager: Sendable {
    static let shared = DeviceIdManager()

    private init() {}

    /// 获取设备唯一标识符
    /// 优先使用 identifierForVendor，失败时使用持久化的 UUID
    var deviceId: String {
        // 1. 尝试获取厂商标识符
        if let vendorId = UIDevice.current.identifierForVendor?.uuidString {
            return vendorId
        }

        // 2. 回退：从 UserDefaults 获取或生成新的 UUID
        let key = "ai_say_device_id"
        if let savedId = UserDefaults.standard.string(forKey: key) {
            return savedId
        }

        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
}
