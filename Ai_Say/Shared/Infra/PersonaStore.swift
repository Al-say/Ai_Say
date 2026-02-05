import SwiftUI
import Combine

// MARK: - Notifications
extension Notification.Name {
    static let personaDidChange = Notification.Name("personaDidChange")
}

@MainActor
final class PersonaStore: ObservableObject {
    static let shared = PersonaStore()

    @AppStorage("userPersona") private var raw: String = UserPersona.examPrep.rawValue
    
    @Published private(set) var current: UserPersona = .examPrep
    
    private init() {
        current = UserPersona(rawValue: raw) ?? .examPrep
    }
    
    func setPersona(_ persona: UserPersona) {
        current = persona
        raw = persona.rawValue
        
        // 发送通知，让其他组件知道角色切换了
        NotificationCenter.default.post(name: .personaDidChange, object: nil)
    }
}