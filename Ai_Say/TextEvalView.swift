import SwiftUI
import UIKit

struct TextEvalView: View {
    @StateObject private var api = APIManager.shared

    @State private var prompt = "Describe your favorite hobby."
    @State private var userText = "My hobby is play basketball. I play it everyday because it make me strong."

    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    Text("✅ TextEvalView 正在运行")
                        .font(.headline)
                        .foregroundStyle(.green)

                    Text(api.serverMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("题目 (Prompt)").font(.headline)
                        TextEditor(text: $prompt)
                            .frame(minHeight: 80)
                            .padding(8)
                            .background(.secondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .focused($isInputFocused)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("你的回答 (User Text)").font(.headline)
                        TextEditor(text: $userText)
                            .frame(minHeight: 140)
                            .padding(8)
                            .background(.secondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .focused($isInputFocused)
                        Text("\(userText.count) 字符")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        isInputFocused = false
                        api.serverMessage = "✅ 按钮已点击"
                        Task {
                            do {
                                _ = try await api.evalText(prompt: prompt, userText: userText)
                            } catch {
                                // Error handled in APIManager
                            }
                        }
                    } label: {
                        HStack {
                            Text(api.isLoading ? "评分中..." : "提交评估")
                            if api.isLoading { ProgressView() }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)

                    if let res = api.evalResult {
                        VStack(spacing: 16) {
                            VStack(spacing: 8) {
                                Text("综合评分").font(.headline)
                                HStack {
                                    ScoreItem(label: "流利度", score: res.fluency)
                                    Spacer()
                                    Divider()
                                    Spacer()
                                    ScoreItem(label: "完整度", score: res.completeness)
                                    Spacer()
                                    Divider()
                                    Spacer()
                                    ScoreItem(label: "相关性", score: res.relevance)
                                }
                                .padding(.vertical, 5)
                            }

                            if let suggestions = res.suggestions, !suggestions.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("AI 建议").font(.headline)
                                    ForEach(suggestions, id: \.self) { sug in
                                        Label(sug, systemImage: "lightbulb.fill")
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }

                            if let issues = res.issues, !issues.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("语法/拼写错误 (\(issues.count))").font(.headline)
                                    ForEach(issues) { issue in
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .foregroundStyle(.red)
                                                Text(issue.message).bold()
                                            }
                                            if let reps = issue.replacements, !reps.isEmpty {
                                                Text("建议改为: \(reps.joined(separator: " / "))")
                                                    .font(.caption)
                                                    .padding(6)
                                                    .background(Color.green.opacity(0.1))
                                                    .cornerRadius(6)
                                            }
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            } else {
                                Text("🎉 太棒了，没有发现明显语法错误！")
                                    .foregroundStyle(.green)
                                    .font(.headline)
                            }
                        }
                    }

                }
                .padding()
            }
            .navigationTitle("AI 口语评分")
        }
    }
}

struct ScoreItem: View {
    let label: String
    let score: Double

    var body: some View {
        VStack(spacing: 4) {
            Text(String(format: "%.0f", score))
                .font(.title2)
                .bold()
                .foregroundStyle(score >= 80 ? .green : (score >= 60 ? .orange : .red))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

