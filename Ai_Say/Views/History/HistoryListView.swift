import SwiftUI
import SwiftData

struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        HistoryRow(item: item)
                    }
                }
            }
            .navigationTitle("历史记录")
            .navigationDestination(for: Item.self) { item in
                HistoryDetailView(item: item)
            }
        } detail: {
            Text("选择一个记录查看详情")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    HistoryListView()
        .modelContainer(for: Item.self, inMemory: true)
}