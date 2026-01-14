// Views/RecordingView.swift
import SwiftUI
import SwiftData
import AVKit

struct RecordingView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm = RecordingViewModel(
        recorder: AudioRecorderService(),
        client: EvalAPIClient.shared
    )

    @State private var player: AVPlayer?

    var body: some View {
        GeometryReader { geo in
            let isWide = geo.size.width >= 900

            NavigationStack {
                ScrollView {
                    if isWide {
                        HStack(alignment: .top, spacing: 16) {
                            leftColumn
                                .frame(maxWidth: 520)
                            rightColumn
                                .frame(maxWidth: .infinity)
                        }
                        .padding(16)
                    } else {
                        VStack(spacing: 16) {
                            leftColumn
                            rightColumn
                        }
                        .padding(16)
                    }
                }
                .navigationTitle("录音评估")
            }
        }
    }

    // MARK: - Left Column (Prompt + Record + Upload)

    private var leftColumn: some View {
        VStack(spacing: 16) {

            AppCard(title: "题目 (Prompt)") {
                TextField("输入题目...", text: $vm.prompt, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isBusyOrRecording)
            }

            AppCard(title: "录音") {
                VStack(spacing: 12) {
                    HStack {
                        // 主按钮：开始/停止
                        Button {
                            vm.toggleRecording()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: recordButtonIcon)
                                Text(recordButtonTitle)
                            }
                            .frame(maxWidth: .infinity, minHeight: 54)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(recordButtonTint)
                        .disabled(recordButtonDisabled)

                        // 试听（录完才出现）
                        if case let .ready(payload) = vm.state {
                            Button {
                                playLocal(payload.fileURL)
                            } label: {
                                Label("试听", systemImage: "play.circle")
                                    .frame(minHeight: 54)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    HStack {
                        Text("时长：\(formatDuration(vm.recorder.duration))")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(stateLabel)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            AppCard(title: "提交") {
                VStack(spacing: 12) {
                    Button {
                        vm.submit(context: modelContext)
                    } label: {
                        HStack(spacing: 8) {
                            Text(submitTitle)
                            if case .uploading = vm.state { ProgressView() }
                        }
                        .frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(submitDisabled)

                    if case let .uploading(progress) = vm.state, let p = progress {
                        ProgressView(value: p)
                        Text("上传进度：\(Int(p * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if case let .failure(message, _) = vm.state {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("重试") {
                            vm.retry(context: modelContext)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    // MARK: - Right Column (Result)

    private var rightColumn: some View {
        VStack(spacing: 16) {

            if case let .success(result, localURL, _) = vm.state {
                AppCard(title: "评估结果") {
                    VStack(spacing: 12) {

                        // 三项分数（0-100）
                        HStack {
                            ScorePill(title: "流利度", value: result.fluency)
                            ScorePill(title: "完整度", value: result.completeness)
                            ScorePill(title: "相关性", value: result.relevance)
                        }

                        // 云端回放（有 audioUrl 才显示）
                        if let audioPath = result.audioUrl,
                           let remoteURL = EvalAPIClient.shared.fullURL(path: audioPath) {
                            Button {
                                playRemote(remoteURL)
                            } label: {
                                Label("播放云端存档", systemImage: "speaker.wave.2")
                                    .frame(maxWidth: .infinity, minHeight: 48)
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        // 本地回放（兜底）
                        Button {
                            playLocal(localURL)
                        } label: {
                            Label("播放本地录音", systemImage: "play.fill")
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.bordered)

                        if let suggestions = result.suggestions, !suggestions.isEmpty {
                            Divider()
                            VStack(alignment: .leading, spacing: 8) {
                                Text("建议")
                                    .font(.headline)
                                ForEach(suggestions, id: \.self) { s in
                                    Text("• \(s)")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if let issues = result.issues, !issues.isEmpty {
                            Divider()
                            VStack(alignment: .leading, spacing: 8) {
                                Text("问题 (\(issues.count))")
                                    .font(.headline)
                                ForEach(issues) { issue in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(issue.message).bold()
                                        if let repl = issue.replacements, !repl.isEmpty {
                                            Text("建议：\(repl.joined(separator: " / "))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            } else {
                AppCard(title: "评估结果") {
                    Text("完成录音并提交后，将在这里显示评分与建议。")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - UI Helpers

    private var isBusyOrRecording: Bool {
        switch vm.state {
        case .recording, .uploading, .requestingPermission:
            return true
        default:
            return false
        }
    }

    private var recordButtonDisabled: Bool {
        // prompt 为空不允许开始录音
        if vm.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        // 上传中不允许动录音
        if case .uploading = vm.state { return true }
        return false
    }

    private var submitDisabled: Bool {
        if case .ready = vm.state { return false }
        return true
    }

    private var submitTitle: String {
        switch vm.state {
        case .uploading:
            return "上传评估中..."
        default:
            return "上传并评估"
        }
    }

    private var recordButtonTitle: String {
        switch vm.state {
        case .recording:
            return "停止录音"
        case .requestingPermission:
            return "请求权限中..."
        default:
            return "开始录音"
        }
    }

    private var recordButtonIcon: String {
        switch vm.state {
        case .recording:
            return "stop.circle.fill"
        default:
            return "mic.circle.fill"
        }
    }

    private var recordButtonTint: Color {
        switch vm.state {
        case .recording:
            return .red
        default:
            return .blue
        }
    }

    private var stateLabel: String {
        switch vm.state {
        case .idle:
            return "空闲"
        case .requestingPermission:
            return "请求权限"
        case .recording:
            return "录音中"
        case .ready:
            return "可提交"
        case .uploading:
            return "上传中"
        case .success:
            return "完成"
        case .failure:
            return "失败"
        }
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let sec = Int(t.rounded())
        let m = sec / 60
        let s = sec % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Playback

    private func playLocal(_ url: URL) {
        player = AVPlayer(playerItem: AVPlayerItem(url: url))
        player?.play()
    }

    private func playRemote(_ url: URL) {
        player = AVPlayer(playerItem: AVPlayerItem(url: url))
        player?.play()
    }
}

// MARK: - Small UI Pieces

private struct AppCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            content
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ScorePill: View {
    let title: String
    let value: Double

    var body: some View {
        VStack(spacing: 4) {
            Text(String(format: "%.0f", value))
                .font(.title3).bold()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}