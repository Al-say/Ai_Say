import SwiftUI
import UIKit

struct TextEvalView: View {
    @StateObject private var api = APIManager.shared

    @State private var prompt = "Describe your favorite hobby."
    @State private var userText = "My hobby is play basketball. I play it everyday because it make me strong."

    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section("题目 (Prompt)") {
                    TextEditor(text: $prompt)
                        .frame(minHeight: 60)
                        .focused($isInputFocused)
                }

                Section("你的回答 (User Text)") {
                    TextEditor(text: $userText)
                        .frame(minHeight: 100)
                        .focused($isInputFocused)
                    Text("\(userText.count) 字符")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        isInputFocused = false
                        print("✅ Submit tapped")
                        api.evalText(prompt: prompt, userText: userText)
                    } label: {
                        HStack {
                            Text(api.isLoading ? "评分中..." : "提交评估")
                            if api.isLoading { ProgressView() }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(api.isLoading || userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Text(api.serverMessage) // 注意：这里不要写 $api.serverMessage
                        .font(.caption)
                        .foregroundStyle(api.serverMessage.contains("❌") ? .red : .gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                if let res = api.evalResult {
                    Section("综合评分") {
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
                        Section("AI 建议") {
                            ForEach(suggestions, id: \.self) { sug in
                                Label(sug, systemImage: "lightbulb.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    if let issues = res.issues, !issues.isEmpty {
                        Section("语法/拼写错误 (\(issues.count))") {
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
                        Section {
                            Text("🎉 太棒了，没有发现明显语法错误！")
                                .foregroundStyle(.green)
                        }
                    }
                }
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

