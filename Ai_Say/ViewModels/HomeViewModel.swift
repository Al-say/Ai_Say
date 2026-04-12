import Foundation
import SwiftUI
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    // MARK: - Published Properties (UI 状态)

    @Published var dailyChallenge: DailyChallengeDTO?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // 用于控制 Banner 的显示状态
    @Published var showDailyChallengeError: Bool = false

    // 🆕 云端历史记录（用于主页显示真实分数）
    @Published var recentRecords: [GrowthHistoryItem] = []

    // MARK: - Dependencies
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init() {
        // 监听 Persona 变化，一旦角色切换，自动刷新每日挑战
        NotificationCenter.default.publisher(for: .personaDidChange)
            .sink { [weak self] _ in
                Task {
                    await self?.fetchDailyChallenge()
                    await self?.fetchRecentHistory()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Intent (业务逻辑)

    /// 核心任务：从服务器获取今日挑战
    func fetchDailyChallenge() async {
        let currentPersona = PersonaStore.shared.current

        // 1. 优先显示缓存（让 UI 瞬间有内容，提升体验）
        if let cached = DailyChallengeCache.load(persona: currentPersona) {
            self.dailyChallenge = cached
        } else {
            self.isLoading = true
        }

        do {
            // 2. 发起网络请求 (调用刚才修好的 API)
            let dto = try await EvalAPIClient.shared.fetchDailyChallenge(persona: currentPersona)

            // 3. 更新 UI 和 缓存
            withAnimation {
                self.dailyChallenge = dto
                self.isLoading = false
                self.errorMessage = nil
                self.showDailyChallengeError = false
            }
            DailyChallengeCache.save(dto, persona: currentPersona)
            print("✅ [HomeVM] 每日挑战加载成功: \(dto.title)")

        } catch {
            print("❌ [HomeVM] 加载失败: \(error.localizedDescription)")
            withAnimation {
                self.isLoading = false
                // 如果没有缓存显示，才报错
                if self.dailyChallenge == nil {
                    self.errorMessage = "无法连接教练服务器，请检查网络"
                    self.showDailyChallengeError = true
                }
            }
        }
    }

    /// 🆕 从云端加载最近的练习记录（包含真实分数）
    func fetchRecentHistory() async {
        do {
            let history = try await EvalAPIClient.shared.fetchGrowthHistory(
                persona: PersonaStore.shared.current,
                limit: 5
            )
            withAnimation {
                self.recentRecords = history
            }
            print("✅ [HomeVM] 最近记录加载成功: \(history.count) 条")
        } catch {
            print("⚠️ [HomeVM] 最近记录加载失败: \(error.localizedDescription)")
            // 不影响主页其他部分显示
        }
    }

    /// 获取当前应该用于练习的 Prompt
    /// 优先级：每日挑战 Prompt > 默认 Prompt
    func getActivePrompt(defaultPrompt: String) -> String {
        return dailyChallenge?.prompt ?? defaultPrompt
    }
}