import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationSplitView {
            List {
                NavigationLink("单次文本评分", destination: SingleShotEvalView())
                NavigationLink("AI 详细评估 (新)", destination: TextEvalView())
            }
            .navigationTitle("Ai_Say")
        } detail: {
            SingleShotEvalView()
        }
    }
}
