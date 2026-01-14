import SwiftUI

/// 简单瀑布流：按"当前列高度最小"分配元素
struct StaggeredGrid<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let columns: Int
    let spacing: CGFloat
    let data: Data
    let content: (Data.Element) -> Content

    init(columns: Int = 2, spacing: CGFloat = 12, data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.columns = max(1, columns)
        self.spacing = spacing
        self.data = data
        self.content = content
    }

    var body: some View {
        GeometryReader { geo in
            let totalSpacing = spacing * CGFloat(columns - 1)
            let itemWidth = (geo.size.width - totalSpacing) / CGFloat(columns)

            HStack(alignment: .top, spacing: spacing) {
                ForEach(0..<columns, id: \.self) { col in
                    VStack(spacing: spacing) {
                        ForEach(items(in: col), id: \.id) { element in
                            content(element)
                                .frame(width: itemWidth)
                        }
                    }
                }
            }
        }
    }

    // 将元素分配到各列（基于估算高度）
    private func items(in column: Int) -> [Data.Element] {
        var cols = Array(repeating: [Data.Element](), count: columns)
        var heights = Array(repeating: CGFloat.zero, count: columns)

        for el in data {
            let idx = heights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            cols[idx].append(el)

            // 估算高度：如果你的 Element 有 heightClass，可做更真实的分布
            let h = estimatedHeight(for: el)
            heights[idx] += h + spacing
        }
        return cols[column]
    }

    private func estimatedHeight(for element: Data.Element) -> CGFloat {
        // 如果 element 有 heightClass（如 Scenario），用 Mirror 读取（MVP 足够）
        let mirror = Mirror(reflecting: element)
        if let hc = mirror.children.first(where: { $0.label == "heightClass" })?.value as? Int {
            switch hc {
            case 1: return 160
            case 2: return 200
            default: return 240
            }
        }
        return 180
    }
}