import SwiftUI

struct M3BottomNavigationBar: View {
    @Binding var selection: MainTab
    private let tabs = MainTab.allCases

    var body: some View {
        HStack {
            ForEach(tabs, id: \.rawValue) { tab in
                item(tab)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 28)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: -2)
    }

    private func item(_ tab: MainTab) -> some View {
        let selected = selection == tab

        return VStack(spacing: 4) {
            ZStack {
                Capsule()
                    .fill(selected ? Color.accentColor.opacity(0.18) : .clear)
                    .frame(width: 66, height: 34)

                Image(systemName: selected ? tab.icon + ".fill" : tab.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(selected ? .primary : .secondary)
            }

            Text(tab.title)
                .font(.caption2)
                .fontWeight(selected ? .bold : .regular)
                .foregroundStyle(selected ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                selection = tab
            }
        }
    }
}