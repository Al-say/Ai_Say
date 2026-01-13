import SwiftUI

struct ContentView: View {
    var body: some View {
        TextEvalView()
            .onAppear { print("✅ App appeared") }
    }
}
