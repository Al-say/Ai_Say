import SwiftUI

struct LoadingOverlay: ViewModifier {
    let isLoading: Bool
    let text: String

    func body(content: Content) -> some View {
        ZStack {
            content

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(text).font(.callout)
                }
                .padding(16)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(radius: 12)
            }
        }
    }
}

extension View {
    func loadingOverlay(_ isLoading: Bool, text: String = "加载中...") -> some View {
        modifier(LoadingOverlay(isLoading: isLoading, text: text))
    }
}