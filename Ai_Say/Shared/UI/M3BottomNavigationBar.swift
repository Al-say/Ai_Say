import SwiftUI

struct M3BottomNavigationBar: View {
    @Binding var selection: MainTab

    var body: some View {
        HStack {
            ForEach(MainTab.allCases, id: \.rawValue) { tab in
                item(tab)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 18) // iPad 通常不需要 34 的 Home Indicator 预留那么多
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemBackground))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
        .shadow(color: .black.opacity(0.06), radius: 10, y: -2)
    }

    private func item(_ tab: MainTab) -> some View {
        let selected = selection == tab

        return VStack(spacing: 6) {
            ZStack {
                Capsule()
                    .fill(selected ? Color.accentColor.opacity(0.18) : Color.clear)
                    .frame(width: 68, height: 34)

                Image(systemName: selected ? "\(tab.icon).fill" : tab.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(selected ? .primary : .secondary)
            }

            Text(tab.title)
                .font(.caption2)
                .fontWeight(selected ? .bold : .regular)
                .foregroundStyle(selected ? .primary : .secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                selection = tab
            }
        }
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}