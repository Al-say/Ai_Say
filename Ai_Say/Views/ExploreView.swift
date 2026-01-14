import SwiftUI

struct ExploreView: View {
    @EnvironmentObject private var router: AppRouter
    @State private var query: String = ""
    @State private var selectedLevel: Scenario.Level? = nil

    private var all: [Scenario] { Scenario.samples }

    private var filtered: [Scenario] {
        all.filter { s in
            let matchLevel = selectedLevel == nil || s.level == selectedLevel
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchQuery = q.isEmpty ||
                s.title.localizedCaseInsensitiveContains(q) ||
                s.subtitle.localizedCaseInsensitiveContains(q) ||
                s.tags.contains(where: { $0.localizedCaseInsensitiveContains(q) })
            return matchLevel && matchQuery
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Search
                    searchBar

                    // Chips
                    levelChips

                    // Empty
                    if filtered.isEmpty {
                        emptyState
                    } else {
                        // iPad：宽屏 3 列，窄屏 2 列（MVP 用 width 粗略判断）
                        GeometryReader { geo in
                            let cols = geo.size.width >= 900 ? 3 : 2
                            StaggeredGrid(columns: cols, spacing: 12, data: filtered) { s in
                                NavigationLink {
                                    ScenarioDetailView(scenario: s) { scenario in
                                        // 跳转到录音评估页
                                        router.goToRecording(prompt: scenario.prompts.first ?? scenario.title)
                                    }
                                } label: {
                                    ScenarioCard(scenario: s)
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
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索场景 / 标签…", text: $query)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var levelChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chip(title: "全部", selected: selectedLevel == nil) {
                    selectedLevel = nil
                }
                ForEach(Scenario.Level.allCases, id: \.rawValue) { lv in
                    chip(title: lv.rawValue, selected: selectedLevel == lv) {
                        selectedLevel = lv
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func chip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
                .foregroundStyle(selected ? .primary : .secondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("没有匹配的场景")
                .font(.headline)
            Text("尝试换个关键词或切换难度。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}