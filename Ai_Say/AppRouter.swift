import SwiftUI
import Combine

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: MainTab = .home
    @Published var sheetRoute: SheetRoute?

    enum SheetRoute: Identifiable, Equatable {
        case recording(prompt: String)
        case changePrompt // 新增：更换题目路由

        var id: String {
            switch self {
            case .recording(let prompt): return "rec_\(prompt)"
            case .changePrompt: return "change_prompt"
            }
        }
    }

    func goToRecording(prompt: String) {
        self.sheetRoute = .recording(prompt: prompt)
    }

    func dismissSheet() {
        self.sheetRoute = nil
    }
}