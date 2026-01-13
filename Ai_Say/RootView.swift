import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationSplitView {
            List {
                NavigationLink("单次文本评分", destination: SingleShotEvalView())
            }
            .navigationTitle("Ai_Say")
        } detail: {
            SingleShotEvalView()
        }
    }
}