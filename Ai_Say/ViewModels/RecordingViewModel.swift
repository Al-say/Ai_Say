// ViewModels/RecordingViewModel.swift
import Foundation
import SwiftData
import Combine

@MainActor
final class RecordingViewModel: ObservableObject {

    // MARK: - State

    struct ReadyPayload: Equatable {
        let fileURL: URL
        let duration: TimeInterval
    }

    struct RetryContext: Equatable {
        let fileURL: URL
        let prompt: String
    }

    enum State {
        case idle
        case requestingPermission
        case recording
        case ready(ReadyPayload)
        case uploading(progress: Double?)      // progress 可选（客户端不实现也没关系）
        case success(result: TextEvalResp, localFileURL: URL, rawBody: String)
        case failure(message: String, retry: RetryContext?)
    }

    @Published var state: State = .idle
    @Published var prompt: String = "Describe your day."

    // 防重复触发（慢网+连点）
    @Published private(set) var isInternalProcessing = false

    private var activeRequestId: UUID? = nil

    // 暴露给 View 绑定（时长/录音中）
    let recorder: AudioRecorderService

    private let client: EvalAPIClient
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        recorder: AudioRecorderService,
        client: EvalAPIClient,
        initialPrompt: String = ""
    ) {
        self.recorder = recorder
        self.client = client
        self.prompt = initialPrompt
        setupSubscribers()
    }

    private func setupSubscribers() {
        recorder.$isRecording
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                self?.handleRecorderStateChange(isRecording: isRecording)
            }
            .store(in: &cancellables)
    }

    private func handleRecorderStateChange(isRecording: Bool) {
        // 如果录音机停止了，但我们的状态还是 .recording，说明是外部原因导致的停止
        if !isRecording, case .recording = state {
            stopRecordingFlow()
        }
    }

    // MARK: - UI Actions

    func toggleRecording() {
        switch state {
        case .idle, .ready, .failure, .success:
            startRecordingFlow()
        case .requestingPermission:
            break
        case .recording:
            stopRecordingFlow()
        case .uploading:
            break
        }
    }

    func submit(context: ModelContext) {
        guard case let .ready(payload) = state, !isInternalProcessing else { return }

        isInternalProcessing = true
        state = .uploading(progress: nil)

        let requestId = UUID()
        activeRequestId = requestId

        client.uploadAudio(
            fileURL: payload.fileURL,
            prompt: prompt,
            progress: { [weak self] p in
                Task { @MainActor in
                    self?.state = .uploading(progress: p)
                }
            },
            completion: { [weak self] result in
                guard let self else { return }
                // ✅ 关键：只处理"最新一次请求"的回调
                guard self.activeRequestId == requestId else { return }

                switch result {
                case .success(let output):
                    self.state = .success(
                        result: output.resp,
                        localFileURL: payload.fileURL,
                        rawBody: output.rawBody
                    )
                    self.saveToSwiftData(
                        resp: output.resp,
                        rawBody: output.rawBody,
                        localFileURL: payload.fileURL,
                        context: context
                    )
                    self.isInternalProcessing = false

                case .failure(let error):
                    self.state = .failure(
                        message: error.localizedDescription,
                        retry: .init(fileURL: payload.fileURL, prompt: self.prompt)
                    )
                    self.isInternalProcessing = false
                }
            }
        )
    }

    func retry(context: ModelContext) {
        guard case let .failure(_, retry?) = state else { return }
        state = .ready(.init(fileURL: retry.fileURL, duration: recorder.duration))
        submit(context: context)
    }

    // MARK: - Private

    private func startRecordingFlow() {
        state = .requestingPermission

        Task {
            let granted = await recorder.requestPermission()
            guard granted else {
                state = .failure(
                    message: "麦克风权限未授权：请到系统设置开启麦克风权限。",
                    retry: nil
                )
                return
            }

            do {
                try recorder.start()
                state = .recording
            } catch {
                state = .failure(message: "录音启动失败：\(error.localizedDescription)", retry: nil)
            }
        }
    }

    private func stopRecordingFlow() {
        recorder.stop()

        guard let url = recorder.lastFileURL else {
            state = .failure(message: "录音文件不存在，请重新录制。", retry: nil)
            return
        }

        // 进入 ready：允许上传 + 试听
        state = .ready(.init(fileURL: url, duration: recorder.duration))
    }

    private func saveToSwiftData(resp: TextEvalResp, rawBody: String, localFileURL: URL, context: ModelContext) {
        // 评分（你现在后端返回 0-100 的三项分数；这里用平均分作为列表展示的 score）
        let score = (resp.fluency + resp.completeness + resp.relevance) / 3.0

        // audioPath MVP 约定：
        // - 优先存后端 audioUrl（相对路径），方便历史记录直接回放云端
        // - 若没有 audioUrl，则存本地文件名（文件名在沙盒中是不变的，但沙盒路径会变）
        let audioPath: String?
        if let remoteUrl = resp.audioUrl {
            audioPath = remoteUrl
        } else {
            // 只存文件名，如 "rec-123456.m4a"
            audioPath = localFileURL.lastPathComponent
        }

        let item = Item(timestamp: Date(), prompt: prompt, userText: nil)
        item.aiResponse = rawBody
        item.score = score
        item.audioPath = audioPath
        item.isAudio = true

        context.insert(item)
        do {
            try context.save()
        } catch {
            // 只记录日志，不影响主流程
            print("❌ SwiftData save failed: \(error)")
        }
    }
}