import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var router: AppRouter
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeContent()
                .navigationTitle("Ai_Say")
                .navigationBarTitleDisplayMode(.large)
                .onChange(of: router.pendingPrompt) { _, newValue in
                    guard newValue != nil else { return }
                    // 自动跳转到录音评估页
                    path.append("recording")
                }
                .navigationDestination(for: String.self) { route in
                    if route == "recording" {
                        RecordingEntryView()
                    }
                }
        }
    }
}

/// 录音入口页：从 router 取 prompt（一次性消费）
struct RecordingEntryView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        let prompt = router.consumePrompt() ?? "Free Talk"
        TextEvalView(initialPrompt: prompt) // 使用现有的TextEvalView
            .navigationTitle("开始练习")
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// Home 内容：抽取出来保持代码整洁
struct HomeContent: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 每日挑战卡片
                dailyChallengeCard

                // 快速开始
                quickStartSection

                // 最近练习
                recentPracticeSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var dailyChallengeCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("今日挑战")
                            .font(.headline)
                        Text("完成 3 次练习，提升流利度")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "flame.fill")
                        .font(.title)
                        .foregroundStyle(.orange)
                }

                ProgressView(value: 0.67)
                    .tint(.orange)

                Text("2 / 3 已完成")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快速开始")
                .font(.title3)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                quickStartButton("话术练习", "text.bubble", .blue)
                quickStartButton("发音练习", "waveform", .green)
                quickStartButton("对话练习", "bubble.left.and.bubble.right", .purple)
            }
        }
    }

    private func quickStartButton(_ title: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 8) {
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
    }

    private var recentPracticeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近练习")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 0) {
                recentPracticeRow("商务英语对话", "2 天前", 85)
                Divider().padding(.leading, 60)
                recentPracticeRow("演讲技巧", "5 天前", 78)
                Divider().padding(.leading, 60)
                recentPracticeRow("日常对话", "1 周前", 92)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func recentPracticeRow(_ title: String, _ time: String, _ score: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Text("\(score)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}