import SwiftUI
import SwiftData

struct HistoryRow: View {
    let item: Item

    var body: some View {
        HStack(spacing: 12) {
            // 类型图标
            ZStack {
                Circle()
                    .fill(item.isAudio ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: item.isAudio ? "mic.fill" : "text.bubble.fill")
                    .foregroundStyle(item.isAudio ? .blue : .green)
            }

            VStack(alignment: .leading, spacing: 4) {
                // 标题
                Text(item.prompt ?? "无标题")
                    .font(.headline)
                    .lineLimit(1)

                // 时间和类型
                HStack {
                    Text(Formatters.iso8601.string(from: item.timestamp))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let score = item.score {
                        Text("分数: \(String(format: "%.1f", score))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    let item = Item(
        timestamp: Date(),
        prompt: "这是一个测试提示",
        userText: "用户输入的文本"
    )

    HistoryRow(item: item)
}