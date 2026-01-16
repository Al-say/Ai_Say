import SwiftUI

struct ExploreView: View {
    @EnvironmentObject private var router: AppRouter

    // 状态
    @State private var scenes: [SceneDTO] = []
    @State private var isLoading: Bool = false
    @State private var scenesError: String?
    @State private var selectedCategory: String = "All"
    
    // 分类选项 (可根据后端实际返回调整)
    private let categories = ["All", "DAILY_LIFE", "IELTS", "TOEFL", "BUSINESS"]

    private func loadScenes() {
        Task {
            isLoading = true
            scenesError = nil
            do {
                let categoryParam = selectedCategory == "All" ? nil : selectedCategory
                let fetchedScenes = try await EvalAPIClient.shared.fetchScenes(
                    persona: PersonaStore.shared.current,
                    category: categoryParam
                )
                scenes = fetchedScenes
                print("✅ Explore scenes loaded: \(fetchedScenes.count)")
            } catch {
                scenesError = "加载场景失败: \(error.localizedDescription)"
                print("❌ Explore error: \(error)")
            }
            isLoading = false
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 🆕 分类筛选栏
                categoryFilterBar
                
                // 内容区域
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if isLoading {
                            loadingState
                        } else if let error = scenesError {
                            errorState(error)
                        } else if scenes.isEmpty {
                            emptyState
                        } else {
                            scenesGrid
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("探索")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemBackground))
            .refreshable {
                loadScenes()
            }
        }
        .onAppear {
            if scenes.isEmpty {
                loadScenes()
            }
        }
        .onChange(of: PersonaStore.shared.current) { _, _ in
            loadScenes()
        }
    }
    
    // MARK: - 分类筛选栏
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories, id: \.self) { category in
                    CategoryPill(
                        title: categoryDisplayName(category),
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                        loadScenes()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemBackground).opacity(0.5))
    }
    
    private func categoryDisplayName(_ category: String) -> String {
        switch category {
        case "All": return "全部"
        case "DAILY_LIFE": return "日常生活"
        case "IELTS": return "雅思"
        case "TOEFL": return "托福"
        case "BUSINESS": return "商务"
        default: return category
        }
    }
    
    // MARK: - 场景网格
    private var scenesGrid: some View {
        GeometryReader { geo in
            let cols = geo.size.width >= 900 ? 3 : 2
            StaggeredGrid(columns: cols, spacing: 12, data: scenes) { scene in
                Button {
                    router.goToRecording(prompt: scene.prompt)
                } label: {
                    SceneCard(scene: scene)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(minHeight: 400)
    }
    
    // MARK: - 状态视图
    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("加载练习场景...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private func errorState(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 34))
                .foregroundStyle(.orange)
            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("重试") {
                loadScenes()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("没有场景")
                .font(.headline)
            Text("当前分类暂无可用场景，试试其他分类吧！")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

// MARK: - 场景卡片
struct SceneCard: View {
    let scene: SceneDTO
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题
            Text(scene.title)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            // 描述/提示
            Text(scene.description ?? scene.prompt)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            // 标签行
            HStack(spacing: 8) {
                if let category = scene.category {
                    CategoryBadge(category: category)
                }
                if let persona = scene.targetPersona {
                    Text(personaDisplayName(persona))
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func personaDisplayName(_ persona: String) -> String {
        switch persona {
        case "EXAM_PREP": return "备考"
        case "CAREER_GROWTH": return "职场"
        default: return persona
        }
    }
}

// MARK: - 分类标签
struct CategoryBadge: View {
    let category: String
    
    var body: some View {
        Text(displayText)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
    
    private var displayText: String {
        switch category {
        case "DAILY_LIFE": return "日常"
        case "BUSINESS": return "商务"
        case "IELTS": return "雅思"
        case "TOEFL": return "托福"
        default: return category
        }
    }
    
    private var color: Color {
        switch category {
        case "DAILY_LIFE": return .green
        case "BUSINESS": return .blue
        case "IELTS": return .purple
        case "TOEFL": return .orange
        default: return .gray
        }
    }
}

// MARK: - 难度标签 (暂未使用，后端未返回)
struct DifficultyBadge: View {
    let difficulty: String
    
    var body: some View {
        Text(displayText)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
    
    private var displayText: String {
        switch difficulty {
        case "HARD": return "困难"
        case "MEDIUM": return "中等"
        case "EASY": return "简单"
        default: return difficulty
        }
    }
    
    private var color: Color {
        switch difficulty {
        case "HARD": return .red
        case "MEDIUM": return .orange
        case "EASY": return .green
        default: return .gray
        }
    }
}

// MARK: - 分类胶囊按钮
struct CategoryPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(isSelected ? Color.accentColor : Color(.tertiarySystemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}