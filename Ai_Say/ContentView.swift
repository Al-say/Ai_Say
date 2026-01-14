import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack { RecordUploadView() }
            .onAppear { print("✅ App appeared") }
    }
}
