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
    @EnvironmentObject var router: AppRouter
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]

    @State private var dailyPrompt: String = "Describe your favorite childhood memory."

    // 每日挑战状态
    @State private var dailyChallenge: DailyChallengeDTO?
    @State private var dailyChallengeError: String?

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

    // 快速入口数据
    private var quickEntries: [QuickEntry] {
        [
            .init(
                title: "职场面试",
                subtitle: "面试题速练",
                icon: "briefcase.fill",
                action: .startRecording(
                    prompt: "Tell me about yourself and your strengths.",
                    persona: .careerGrowth
                )
            ),
            .init(
                title: "旅行社交",
                subtitle: "机场/酒店/点餐",
                icon: "airplane",
                action: .startRecording(
                    prompt: "You are at a hotel. Ask for an early check-in politely.",
                    persona: .careerGrowth
                )
            ),
            .init(
                title: "自由表达",
                subtitle: "不限主题",
                icon: "quote.bubble.fill",
                action: .startRecording(prompt: "Describe your day in detail.")
            ),
            .init(
                title: "收藏题目",
                subtitle: "题库与收藏",
                icon: "star.fill",
                action: .openPromptPicker
            )
        ]
    }

    var body: some View {
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
                    PromptPickerSheet(currentPrompt: $dailyPrompt, historyPrompts: historyPrompts)
                        .presentationDetents([.medium, .large])
                }
            }
            .onChange(of: router.sheetRoute) {
                // 当 sheet 被系统关闭时（newValue == nil），做一次清理
                if $0 == nil {
                    router.dismissSheet()
                }
            }
            .onAppear {
                loadDailyChallenge()
            }
            .onChange(of: PersonaStore.shared.current) { _ in
                loadDailyChallenge()
            }
        }
    }

    // MARK: - 左侧：任务流 (Task Column)
    private var leftTaskColumn: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 今日挑战卡片
            if let challenge = dailyChallenge {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Label("今日挑战", systemImage: "sparkles")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.accentColor)
                        Spacer()
                        Button("更换题目") {
                            router.showPromptPicker() // ✅ 触发更稳健的路由
                        }
                            .font(.caption.bold())
                    }

                    Text(challenge.title)
                        .font(.title3.bold())
                        .lineLimit(3)

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
                .background(Color.accentColor.opacity(0.12)) // M3 Tonal 高亮
                .clipShape(RoundedRectangle(cornerRadius: 28))
            } else if let error = dailyChallengeError {
                VStack(alignment: .leading, spacing: 16) {
                    Text("今日挑战")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.accentColor)
                    Text("加载失败：\(error)")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Button("重试") {
                        loadDailyChallenge()
                    }
                    .font(.caption.bold())
                }
                .padding(24)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 28))
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text("今日挑战")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.accentColor)
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(24)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 28))
            }

            // 场景入口 2x2 Grid
            Text("快速练习").font(.headline).padding(.leading, 8)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(quickEntries) { entry in
                    QuickEntryCard(entry: entry) { tapped in
                        handleQuickEntry(tapped)
                    }
                }
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
            let prompt = dailyChallenge?.prompt ?? dailyPrompt
            router.goToRecording(prompt: prompt)
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
        .offset(y: 100)
    }

    // MARK: - 辅助函数
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

    private func loadDailyChallenge() {
        let persona = PersonaStore.shared.current

        if let cached = DailyChallengeCache.load(persona: persona) {
            dailyChallenge = cached
            return
        }

        EvalAPIClient.shared.fetchDailyChallenge(persona: persona) { result in
            switch result {
            case .success(let dto):
                self.dailyChallenge = dto
                self.dailyChallengeError = nil
                DailyChallengeCache.save(dto, persona: persona)
            case .failure(let msg):
                self.dailyChallengeError = msg
            }
        }
    }

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