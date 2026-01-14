import SwiftUI

struct ErrorBanner: View {
    let message: String
    var retryTitle: String = "重试"
    var onRetry: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 6) {
                Text("出错了").bold()
                Text(message).font(.callout)
            }

            Spacer()

            if let onRetry {
                Button(retryTitle, action: onRetry)
                    .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}