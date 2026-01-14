import SwiftUI
import Combine

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: MainTab = .home
    @Published var sheetRoute: SheetRoute?

    enum SheetRoute: Identifiable, Equatable {
        case recording(prompt: String)
        case changePrompt

        var id: String {                     // ✅ 必须提供 id
            switch self {
            case .recording(let prompt): return "recording:\(prompt)"
            case .changePrompt: return "changePrompt"
            }
        }
    }

    func goToRecording(prompt: String) {
        sheetRoute = .recording(prompt: prompt)
    }

    func showPromptPicker() {
        sheetRoute = .changePrompt
    }

    func dismissSheet() {
        sheetRoute = nil
    }
}