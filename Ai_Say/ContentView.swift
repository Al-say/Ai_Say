import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "hand.thumbsdown.fill")
                .font(.system(size: 64))
                .symbolRenderingMode(.multicolor)

            Text("不好世界")
                .font(.largeTitle)
                .bold()

            Text("Bad, World!")
                .font(.title3)
                .foregroundStyle(.secondary)

            Divider().padding(.horizontal)

            Text("本地界面测试（不联网）")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
