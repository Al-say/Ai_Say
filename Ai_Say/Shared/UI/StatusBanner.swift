import SwiftUI

struct StatusBanner: View {
    enum Kind { case info, warning, success, error }

    let kind: Kind
    let text: String

    var body: some View {
        HStack {
            Circle().frame(width: 10, height: 10)
            Text(text).font(.callout)
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .foregroundStyle(.primary)
        .tint(colorFor(kind))
    }

    private func colorFor(_ k: Kind) -> Color {
        switch k {
        case .info: return .blue
        case .warning: return .orange
        case .success: return .green
        case .error: return .red
        }
    }
}