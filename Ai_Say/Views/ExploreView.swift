import SwiftUI

struct ExploreView: View {
    @EnvironmentObject private var router: AppRouter

    // Scenes 状态
    @State private var scenes: [SceneDTO] = []
    @State private var scenesError: String?

    private func loadScenes() {
        Task {
            do {
                scenesError = nil
                let fetchedScenes = try await EvalAPIClient.shared.fetchScenes(persona: PersonaStore.shared.current)
                scenes = fetchedScenes
            } catch {
                scenesError = "加载场景失败: \(error.localizedDescription)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Empty
                    if scenes.isEmpty && scenesError == nil {
                        emptyState
                    } else if let error = scenesError {
                        Text("错误: \(error)")
                            .foregroundColor(.red)
                            .padding()
                    } else {
                        // iPad：宽屏 3 列，窄屏 2 列（MVP 用 width 粗略判断）
                        GeometryReader { geo in
                            let cols = geo.size.width >= 900 ? 3 : 2
                            StaggeredGrid(columns: cols, spacing: 12, data: scenes) { scene in
                                Button {
                                    // 使用场景的 prompt 跳转到录音评估页
                                    router.goToRecording(prompt: scene.prompt)
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(scene.title)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text(scene.prompt)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                        if let persona = scene.targetPersona {
                                            Text("适合: \(persona)")
                                                .font(.caption)
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(minHeight: 400) // 避免 GeometryReader 高度为 0
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }
            .navigationTitle("探索")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemBackground))
        }
        .onAppear {
            loadScenes()
        }
        .onChange(of: PersonaStore.shared.current) { _ in
            loadScenes()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("没有场景")
                .font(.headline)
            Text("暂时没有可用的场景，请稍后再试。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}