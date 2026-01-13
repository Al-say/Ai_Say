import SwiftUI

struct SingleShotEvalView: View {
    @ObservedObject private var api = APIManager.shared

    @State private var prompt: String = "Describe your favorite hobby in 3-5 sentences."
    @State private var userText: String = ""
    @State private var isSubmitting: Bool = false

    // 先用本地假数据占位，接后端后用 api.evalResult 替换
    @State private var scores: (fluency: Double, completeness: Double, relevance: Double)? = nil
    @State private var suggestions: [String] = []

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
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Text("提交评分")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSubmit || isSubmitting)

                    Button {
                        reset()
                    } label: {
                        Text("清空")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSubmitting)
                }

                Text(api.serverMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let s = scores {
                Section("评分结果") {
                    ScoreRow(title: "流利度 Fluency", value: s.fluency)
                    ScoreRow(title: "完整度 Completeness", value: s.completeness)
                    ScoreRow(title: "相关性 Relevance", value: s.relevance)
                }

                Section("建议") {
                    if suggestions.isEmpty {
                        Text("暂无建议")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(suggestions, id: \.self) { item in
                            Text("• \(item)")
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
        isSubmitting = true
        api.serverMessage = "评分中..."

        // TODO：把这里替换成你的后端调用（成功后写入 scores/suggestions）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.scores = (fluency: 86.0, completeness: 78.0, relevance: 82.0)
            self.suggestions = [
                "减少重复词，尝试使用同义替换。",
                "补充一个具体例子来增强完整度。",
                "注意句子之间的衔接词（however / therefore）。"
            ]
            self.api.serverMessage = "✅ 评分完成"
            self.isSubmitting = false
        }
    }

    private func reset() {
        userText = ""
        scores = nil
        suggestions = []
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