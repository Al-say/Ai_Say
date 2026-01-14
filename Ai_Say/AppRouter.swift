import SwiftUI
import Combine

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: MainTab = .home

    // 用于跨 Tab 传参（例如 Explore 选中的 prompt）
    @Published var pendingPrompt: String? = nil

    func goToRecording(prompt: String) {
        pendingPrompt = prompt
        selectedTab = .home   // 或者 .home 内部再 push 到 Recording
    }

    func consumePrompt() -> String? {
        defer { pendingPrompt = nil }
        return pendingPrompt
    }
}