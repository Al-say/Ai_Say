import Foundation
import os.log

enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Ai_Say"
    private static let network = OSLog(subsystem: subsystem, category: "network")
    private static let audio = OSLog(subsystem: subsystem, category: "audio")
    private static let ui = OSLog(subsystem: subsystem, category: "ui")

    static func net(_ msg: String) { os_log("%{public}@", log: network, type: .info, msg) }
    static func netError(_ msg: String) { os_log("%{public}@", log: network, type: .error, msg) }

    static func audio(_ msg: String) { os_log("%{public}@", log: audio, type: .info, msg) }
    static func audioError(_ msg: String) { os_log("%{public}@", log: audio, type: .error, msg) }

    static func ui(_ msg: String) { os_log("%{public}@", log: ui, type: .info, msg) }
}