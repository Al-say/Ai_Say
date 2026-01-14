import SwiftUI
import SwiftData
import UIKit

struct HistoryDetailView: View {
    let item: Item

    @State private var parsed: TextEvalResp?
    @State private var shareImage: UIImage?
    @State private var selectedIssue: Issue? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 基本信息
                AppCard(title: "基本信息") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("类型:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(item.isAudio ? "音频评估" : "文本评估")
                                .font(.subheadline)
                        }

                        HStack {
                            Text("时间:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(Formatters.iso8601.string(from: item.timestamp))
                                .font(.subheadline)
                        }

                        if let score = item.score {
                            HStack {
                                Text("总分:")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "%.1f", score))
                                    .font(.title3)
                                    .bold()
                                    .foregroundStyle(score >= 80 ? .green : score >= 60 ? .orange : .red)
                            }
                        }
                    }
                }

                // 提示词
                if let prompt = item.prompt {
                    AppCard(title: "提示词") {
                        Text(prompt)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // 用户输入
                if let userText = item.userText {
                    AppCard(title: "用户输入") {
                        VStack(alignment: .leading, spacing: 12) {
                            if let issues = parsed?.issues, !issues.isEmpty {
                                IssueHighlightedTextView(
                                    text: userText,
                                    issues: issues
                                ) { issue in
                                    selectedIssue = issue
                                }
                                .padding(16)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            } else {
                                Text(userText)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            // 显示选中的issue详情
                            if let issue = selectedIssue {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                        Text("建议修改")
                                            .font(.subheadline).bold()
                                        Spacer()
                                        Button {
                                            selectedIssue = nil
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 12, weight: .bold))
                                        }
                                    }
                                    .foregroundStyle(.secondary)

                                    Text(issue.message)
                                        .font(.body)

                                    if let reps = issue.replacements, !reps.isEmpty {
                                        Text("推荐：\(reps.joined(separator: " / "))")
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(16)
                                .background(Color.accentColor.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                }

                // AI回复
                if let aiResponse = item.aiResponse {
                    AppCard(title: "AI回复") {
                        Text(aiResponse)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // 音频文件路径（如果有）
                if let audioPath = item.audioPath {
                    AppCard(title: "音频文件") {
                        Text(audioPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // 分享功能
                if parsed != nil {
                    AppCard(title: "分享报告") {
                        VStack(spacing: 16) {
                            // 生成按钮
                            Button("生成成绩单") {
                                guard let p = parsed else { return }
                                let dims = RadarMapper.from(resp: p)
                                shareImage = ResultShareService.renderReport(
                                    title: "Speaking Assessment Report",
                                    resp: p,
                                    dimensions: dims
                                )
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)

                            // 分享（有图才出现）
                            if let img = shareImage {
                                ShareLink(item: Image(uiImage: img), preview: SharePreview("Report", image: Image(uiImage: img))) {
                                    Label("分享", systemImage: "square.and.arrow.up")
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("详情")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            parseResponse()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selectedIssue?.id)
    }

    private func parseResponse() {
        guard let aiResponse = item.aiResponse else { return }
        do {
            let data = aiResponse.data(using: .utf8) ?? Data()
            parsed = try JSONDecoder().decode(TextEvalResp.self, from: data)
        } catch {
            print("解析响应失败: \(error)")
        }
    }
}

#Preview {
    let item = Item(
        timestamp: Date(),
        prompt: "请描述一下人工智能的发展历程",
        userText: "人工智能的发展经历了几个重要阶段。首先是20世纪50年代的诞生期，然后是70-80年代的知识工程时期，接着是90年代的机器学习兴起，现在是深度学习的时代。"
    )

    NavigationStack {
        HistoryDetailView(item: item)
    }
}