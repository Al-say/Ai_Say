import SwiftUI
import SwiftData

/// 快速入口模型
struct QuickEntry: Identifiable {
    enum Action {
        case startRecording(prompt: String, persona: UserPersona? = nil)
        case openPromptPicker
        case switchTab(MainTab)
    }

    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let action: Action
}

/// 主页视图，展示用户的主要界面，包括任务、历史记录和快速入口
struct HomeView: View {
    // MARK: - Properties
    @EnvironmentObject var router: AppRouter
    @Environment(\.modelContext) private var modelContext

    // 🧠 引入 ViewModel (MVVM)
    @StateObject private var vm = HomeViewModel()

    // 💾 历史记录依然从 SwiftData 读取 (作为本地缓存的单一事实来源)
    // 假设你在 ResultView 中已经把评估结果保存到了 SwiftData 的 Item 模型中
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]

    @State private var defaultPrompt: String = "Describe your favorite childhood memory."

    // 💡 提取最近 5 条不重复的历史 Prompt
    private var historyPrompts: [String] {
        let allPrompts = items.compactMap { $0.prompt }
        var unique: [String] = []
        for p in allPrompts where !unique.contains(p) {
            unique.append(p)
            if unique.count >= 5 { break }
        }
        return unique
    }

    // 静态配置：快速入口
    private var quickEntries: [QuickEntry] {
        [
            .init(title: "职场面试", subtitle: "面试题速练", icon: "briefcase.fill",
                  action: .startRecording(prompt: "Tell me about yourself and your strengths.", persona: .careerGrowth)),
            .init(title: "旅行社交", subtitle: "机场/酒店/点餐", icon: "airplane",
                  action: .startRecording(prompt: "You are at a hotel. Ask for an early check-in politely.", persona: .dailyLife)), // 修正 persona
            .init(title: "自由表达", subtitle: "不限主题", icon: "quote.bubble.fill",
                  action: .startRecording(prompt: "Describe your day in detail.")),
            .init(title: "收藏题目", subtitle: "题库与收藏", icon: "star.fill",
                  action: .openPromptPicker)
        ]
    }

    // MARK: - Body
    var body: some View {
        mainContentView
            // 🚀 核心生命周期：页面出现时加载数据
            .task {
                await vm.fetchDailyChallenge()
                await vm.fetchRecentHistory()
            }
            // 当 Sheet 关闭时清理路由状态
            .onChange(of: router.sheetRoute) { _, newValue in
                if newValue == nil { router.dismissSheet() }
            }
    }

    // MARK: - 主内容视图
    private var mainContentView: some View {
        NavigationStack {
            ZStack(alignment: .center) {
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
            // ✅ 统一 Sheet 路由入口
            .sheet(item: $router.sheetRoute) { route in
                switch route {
                case .recording(let prompt):
                    RecordingView(initialPrompt: prompt)

                case .changePrompt:
                    PromptPickerSheet(currentPrompt: $defaultPrompt, historyPrompts: historyPrompts)
                        .presentationDetents([.medium, .large])
                }
            }
        }
    }

    // MARK: - Left Column: Task Flow
    private var leftTaskColumn: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 1. 今日挑战卡片 (绑定 ViewModel 数据)
            DailyChallengeCardView(
                challenge: vm.dailyChallenge,
                isLoading: vm.isLoading,
                error: vm.errorMessage,
                onRetry: {
                    Task { await vm.fetchDailyChallenge() }
                },
                onChangePrompt: {
                    router.showPromptPicker()
                }
            )

            // 2. 快速入口 Grid
            Text("快速练习").font(.headline).padding(.leading, 8)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(quickEntries) { entry in
                    QuickEntryCard(entry: entry) { handleQuickEntry($0) }
                }
            }
        }
    }

    // MARK: - Right Column: Info Flow
    private var rightInfoColumn: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 1. 最近表现 (使用云端数据显示真实分数)
            if let latest = vm.recentRecords.first {
                CloudRecentPerformanceCard(record: latest)
            } else if let lastItem = items.first {
                RecentPerformanceCard(item: lastItem)
            } else {
                EmptyStateCard(text: "完成第一次练习后\n解锁成长报告")
            }

            // 2. 历史记录预览 (使用云端数据)
            Text("练习记录").font(.headline)
            CloudHistoryPreviewList(records: Array(vm.recentRecords.prefix(3)), onSeeAll: {
                router.selectedTab = .growth
            })
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
    }

    // MARK: - Primary CTA (FAB)
    private var primaryFAB: some View {
        Button {
            // 🔥 这里使用了 ViewModel 中的真实数据
            let promptToUse = vm.getActivePrompt(defaultPrompt: defaultPrompt)
            router.goToRecording(prompt: promptToUse)
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
            .shadow(color: .accentColor.opacity(0.4), radius: 10, y: 5)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 100) // 抬高，避免被底部导航栏遮挡
        .frame(maxHeight: .infinity, alignment: .bottom) // 确保固定在底部
    }

    // MARK: - Actions
    private func handleQuickEntry(_ entry: QuickEntry) {
        switch entry.action {
        case .startRecording(let prompt, let persona):
            if let persona { PersonaStore.shared.setPersona(persona) }
            router.sheetRoute = .recording(prompt: prompt)
        case .openPromptPicker:
            router.sheetRoute = .changePrompt
        case .switchTab(let tab):
            router.selectedTab = tab
        }
    }

    // MARK: - 认证相关方法



    // MARK: - 登录视图


    // 处理 Apple 登录
}

// MARK: - Subviews (Refactored for Cleanliness)

/// 抽取出来的今日挑战卡片，使主 View 更整洁
struct DailyChallengeCardView: View {
    let challenge: DailyChallengeDTO?
    let isLoading: Bool
    let error: String?
    let onRetry: () -> Void
    let onChangePrompt: () -> Void

    var body: some View {
        Group {
            if let challenge = challenge {
                // 成功状态
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Label("今日挑战", systemImage: "sparkles")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.accentColor)
                        Spacer()
                        Button("更换题目", action: onChangePrompt)
                            .font(.caption.bold())
                    }

                    Text(challenge.title)
                        .font(.title3.bold())
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true) // 防止被截断

                    Text(challenge.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack {
                        Label(challenge.difficulty, systemImage: "gauge.medium")
                        Label("建议 2min", systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(24)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 28))

            } else if let error = error {
                // 错误状态
                VStack(alignment: .leading, spacing: 16) {
                    Label("网络连接中断", systemImage: "wifi.slash")
                        .font(.subheadline.bold())
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("点击重试", action: onRetry)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 28))

            } else {
                // 加载状态 (骨架屏效果)
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Rectangle().fill(Color.gray.opacity(0.2)).frame(width: 80, height: 20).cornerRadius(4)
                        Spacer()
                    }
                    Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 24).cornerRadius(4)
                    Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 24).cornerRadius(4).padding(.trailing, 40)
                    Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 40).cornerRadius(4)
                }
                .padding(24)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 28))
            }
        }
        .animation(.spring(), value: isLoading)
    }
}

/// 最近表现卡片
struct RecentPerformanceCard: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近表现").font(.headline)

            HStack(spacing: 15) {
                ScoreMiniCircle(score: scoreInt(item), label: "总分")
                VStack(alignment: .leading, spacing: 4) {
                    Text("上次练习：\(item.timestamp.formatted(.dateTime.month().day().hour().minute()))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(getEncouragement(score: scoreInt(item)))
                        .font(.caption.bold())
                        .foregroundStyle(getScoreColor(score: scoreInt(item)))
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
    }

    private func scoreInt(_ item: Item) -> Int {
        Int((item.score ?? 0).rounded())
    }

    private func getEncouragement(score: Int) -> String {
        switch score {
        case 90...100: return "表现完美，大师级水准！"
        case 80..<90:  return "进步显著，继续保持！"
        case 60..<80:  return "基础扎实，再接再厉。"
        default:       return "只要开口，就是进步。"
        }
    }

    private func getScoreColor(score: Int) -> Color {
        score >= 80 ? .green : (score >= 60 ? .orange : .gray)
    }
}

/// 历史列表组件
struct HistoryPreviewList: View {
    let items: [Item]
    let onSeeAll: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                HStack {
                    Circle().fill(Color.accentColor).frame(width: 8, height: 8)
                    Text(item.timestamp, format: .dateTime.month().day())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(item.isAudio ? "口语评估" : "文本评估")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int((item.score ?? 0).rounded()))")
                        .font(.subheadline.bold())
                        .monospacedDigit()
                        .foregroundStyle(Color.accentColor)
                }
                .padding(.vertical, 12)

                if idx != items.count - 1 {
                    Divider()
                }
            }

            if items.isEmpty {
                Text("暂无记录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                Button("查看全部历史", action: onSeeAll)
                    .font(.caption.bold())
                    .padding(.top, 14)
            }
        }
    }
}

// MARK: - 辅助组件

/// 快速练习入口卡片
struct QuickEntryCard: View {
    let entry: QuickEntry
    let onTap: (QuickEntry) -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap(entry)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: entry.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title).font(.headline)
                    Text(entry.subtitle).font(.caption).foregroundStyle(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(entry.title)
        .accessibilityHint(entry.subtitle)
    }
}

/// 分数圆形显示组件，带进度环
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

/// 空状态卡片，用于显示无数据时的提示
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

// MARK: - 🆕 云端数据 UI 组件

/// 最近表现卡片 - 使用云端 GrowthHistoryItem
struct CloudRecentPerformanceCard: View {
    let record: GrowthHistoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近表现").font(.headline)

            HStack(spacing: 15) {
                ScoreMiniCircle(score: record.overallValue, label: "总分")
                VStack(alignment: .leading, spacing: 4) {
                    Text("上次练习：\(formatDate(record.createdAt))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(getEncouragement(score: record.overallValue))
                        .font(.caption.bold())
                        .foregroundStyle(getScoreColor(score: record.overallValue))
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
    }

    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            return date.formatted(.dateTime.month().day().hour().minute())
        }
        // fallback: 不含小数秒
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoString) {
            return date.formatted(.dateTime.month().day().hour().minute())
        }
        return String(isoString.prefix(10))
    }

    private func getEncouragement(score: Int) -> String {
        switch score {
        case 90...100: return "表现完美，大师级水准！"
        case 80..<90:  return "进步显著，继续保持！"
        case 60..<80:  return "基础扎实，再接再厉。"
        default:       return "只要开口，就是进步。"
        }
    }

    private func getScoreColor(score: Int) -> Color {
        score >= 80 ? .green : (score >= 60 ? .orange : .gray)
    }
}

/// 历史列表组件 - 使用云端 GrowthHistoryItem
struct CloudHistoryPreviewList: View {
    let records: [GrowthHistoryItem]
    let onSeeAll: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(records.enumerated()), id: \.element.id) { idx, record in
                HStack {
                    Circle().fill(Color.accentColor).frame(width: 8, height: 8)
                    Text(record.date)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("口语评估")
                        .font(.subheadline)
                    Spacer()
                    Text("\(record.overallValue)")
                        .font(.subheadline.bold())
                        .monospacedDigit()
                        .foregroundStyle(record.overallValue > 0 ? Color.accentColor : .secondary)
                }
                .padding(.vertical, 12)

                if idx != records.count - 1 {
                    Divider()
                }
            }

            if records.isEmpty {
                Text("暂无记录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                Button("查看全部历史", action: onSeeAll)
                    .font(.caption.bold())
                    .padding(.top, 14)
            }
        }
    }
}