import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationSplitView {
            List {
                NavigationLink("单次文本评分", destination: SingleShotEvalView())
                NavigationLink("AI 详细评估 (新)", destination: TextEvalView())
                NavigationLink("口语录音评分", destination: RecordingView())
                NavigationLink("历史记录", destination: HistoryListView())
            }
            .navigationTitle("Ai_Say")
        } detail: {
            SingleShotEvalView()
        }
    }
}
