import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject var router: AppRouter
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]

    // 模拟今日挑战数据
    private var dailyPrompt = "Describe your favorite childhood memory."

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    // 使用 ViewThatFits 处理 iPad 横竖屏自适应
                    ViewThatFits(in: .horizontal) {
                        // 1. 横屏：双栏布局
                        HStack(alignment: .top, spacing: 24) {
                            leftTaskColumn.frame(maxWidth: .infinity)
                            rightInfoColumn.frame(width: 360)
                        }
                        .padding(24)

                        // 2. 竖屏/窄屏：单栏堆叠
                        VStack(spacing: 24) {
                            leftTaskColumn
                            rightInfoColumn
                        }
                        .padding(20)
                    }
                    .padding(.bottom, 120) // 给底栏和 FAB 留空间
                }
                .background(Color(.systemBackground))
                .navigationTitle("EchoLingua")

                // 3. Primary CTA: Extended FAB (悬浮行动按钮)
                primaryFAB
            }
            // 监听路由跳转
            .sheet(item: Binding(
                get: { router.pendingPrompt.map { IdentifiableString(val: $0) } },
                set: { _ in _ = router.consumePrompt() }
            )) { promptObj in
                RecordingView(initialPrompt: promptObj.val)
            }
        }
    }

    // MARK: - 左侧：任务流 (Task Column)
    private var leftTaskColumn: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 今日挑战卡片
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("今日挑战", systemImage: "sparkles")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.accentColor)
                    Spacer()
                    Button("更换题目") { /* 弹出题目选择 Sheet */ }
                        .font(.caption.bold())
                }

                Text(dailyPrompt)
                    .font(.title3.bold())
                    .lineLimit(3)

                HStack {
                    Label("中级", systemImage: "gauge.medium")
                    Label("建议 2min", systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(Color.accentColor.opacity(0.12)) // M3 Tonal 高亮
            .clipShape(RoundedRectangle(cornerRadius: 28))

            // 场景入口 2x2 Grid
            Text("快速练习").font(.headline).padding(.leading, 8)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickEntryCard(title: "职场面试", icon: "briefcase.fill", color: .blue)
                QuickEntryCard(title: "旅行社交", icon: "airplane", color: .orange)
                QuickEntryCard(title: "自由表达", icon: "quote.bubble.fill", color: .purple)
                QuickEntryCard(title: "收藏题目", icon: "star.fill", color: .yellow)
            }
        }
    }

    // MARK: - 右侧：复盘流 (Info Column)
    private var rightInfoColumn: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 最近一次结果快照
            if let lastItem = items.first {
                VStack(alignment: .leading, spacing: 12) {
                    Text("最近表现").font(.headline)

                    HStack(spacing: 15) {
                        ScoreMiniCircle(score: scoreInt(lastItem), label: "总分")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("上次练习：\(lastItem.timestamp.formatted(.dateTime.month().day().hour().minute()))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("进步显著，继续保持！")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                }
            } else {
                // 空态显示
                EmptyStateCard(text: "完成第一次练习后\n解锁成长报告")
            }

            // 历史列表预览
            Text("练习记录").font(.headline)
            historyPreviewList
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 24))
        }
    }

    // MARK: - Primary CTA (FAB)
    private var primaryFAB: some View {
        Button {
            router.goToRecording(prompt: dailyPrompt)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mic.fill")
                    .font(.title2)
                Text("开始练习")
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
        .padding(32)
    }

    // MARK: - 辅助函数
    private func scoreInt(_ item: Item) -> Int {
        // 兼容 Double? / nil
        let v = item.score ?? 0
        // 兼容异常值
        let clamped = min(max(v, 0), 100)
        return Int(clamped.rounded())
    }

    private var displayItems: [Item] {
        Array(items.prefix(3))
    }

    // 最近记录列表（修复尾部分割线）
    private var historyPreviewList: some View {
        VStack(spacing: 0) {
            let list = displayItems
            ForEach(Array(list.enumerated()), id: \.element.id) { idx, item in
                HStack {
                    Circle().fill(Color.accentColor).frame(width: 8, height: 8)
                    Text(item.timestamp, format: .dateTime.month().day())
                        .font(.caption.monospacedDigit())
                    Text(item.isAudio ? "口语评估" : "文本评估")
                        .font(.subheadline)
                    Spacer()
                    Text("\(scoreInt(item))")
                        .font(.subheadline.bold())
                        .monospacedDigit()
                }
                .padding(.vertical, 12)

                if idx != list.count - 1 {
                    Divider()
                }
            }
            Button("查看全部历史") {
                router.selectedTab = .growth // 跳转到成长/历史
            }
            .font(.caption.bold())
            .padding(.top, 10)
        }
    }
}

// MARK: - 辅助组件

struct QuickEntryCard: View {
    let title: String; let icon: String; let color: Color
    @EnvironmentObject var router: AppRouter

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .onTapGesture {
            // 暂时打日志，后续可以跳转到对应场景
            print("Tapped: \(title)")
            // 示例：跳转到explore tab选择题目
            router.selectedTab = .explore
        }
    }
}

struct ScoreMiniCircle: View {
    let score: Int; let label: String

    var body: some View {
        let progress = min(max(Double(score) / 100.0, 0), 1)

        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.12), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.system(.subheadline, design: .monospaced)).bold()
                Text(label)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 50, height: 50)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
    }
}

struct EmptyStateCard: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption).multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.tertiary)
            )
    }
}

// 辅助包装类
struct IdentifiableString: Identifiable {
    let id = UUID()
    let val: String
}