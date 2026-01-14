import SwiftUI

struct SingleShotEvalView: View {
    @ObservedObject private var api = APIManager.shared

    @State private var prompt: String = "Describe your favorite hobby in 3-5 sentences."
    @State private var userText: String = ""

    var body: some View {
        List {
            Section("题目 Prompt") {
                TextEditor(text: $prompt)
                    .frame(minHeight: 90)
            }

            Section("你的回答") {
                TextEditor(text: $userText)
                    .frame(minHeight: 180)

                HStack {
                    Text("\(userText.count)/4000")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            Section {
                HStack(spacing: 12) {
                    Button {
                        submit()
                    } label: {
                        if api.isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Text("提交评分")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSubmit || api.isLoading)

                    Button {
                        reset()
                    } label: {
                        Text("清空")
                    }
                    .buttonStyle(.bordered)
                    .disabled(api.isLoading)
                }

                Text(api.serverMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let res = api.evalResult {
                Section("评分结果") {
                    ScoreRow(title: "流利度 Fluency", value: res.fluency)
                    ScoreRow(title: "完整度 Completeness", value: res.completeness)
                    ScoreRow(title: "相关性 Relevance", value: res.relevance)
                }

                Section("建议") {
                    if let suggestions = res.suggestions, !suggestions.isEmpty {
                        ForEach(suggestions, id: \.self) { item in
                            Text("• \(item)")
                        }
                    } else {
                        Text("暂无建议")
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let issues = res.issues, !issues.isEmpty {
                    Section("语法问题") {
                        ForEach(issues) { issue in
                            VStack(alignment: .leading) {
                                Text(issue.message).bold()
                                if let reps = issue.replacements, !reps.isEmpty {
                                    Text("建议: \(reps.joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }
            } else {
                Section("评分结果") {
                    Text("提交后显示分数与建议")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("单次文本评分")
    }

    private var canSubmit: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        Task {
            do {
                _ = try await api.evalText(prompt: prompt, userText: userText)
            } catch {
                // Error is handled in APIManager by setting serverMessage
            }
        }
    }

    private func reset() {
        userText = ""
        api.evalResult = nil
        api.serverMessage = "等待连接..."
    }
}

private struct ScoreRow: View {
    let title: String
    let value: Double

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(String(format: "%.1f", value))
                .monospacedDigit()
        }
    }
}