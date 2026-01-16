import SwiftUI
import Combine

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
    }
}