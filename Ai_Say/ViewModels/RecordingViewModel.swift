// ViewModels/RecordingViewModel.swift
import Foundation
import SwiftData
import Combine

enum EvaluationState: Equatable {
    case idle
    case requestingPermission
    case recording
    case ready(RecordingPayload)
    case uploading
    case success(TextEvalResp, URL, String?)
    case failure(String)

    static func == (lhs: EvaluationState, rhs: EvaluationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.requestingPermission, .requestingPermission),
             (.recording, .recording),
             (.uploading, .uploading):
            return true
        case let (.ready(lhsPayload), .ready(rhsPayload)):
            return lhsPayload == rhsPayload
        case let (.success(lhsResp, lhsURL, lhsRaw), .success(rhsResp, rhsURL, rhsRaw)):
            return lhsResp.recordId == rhsResp.recordId &&
                   lhsResp.fluency == rhsResp.fluency &&
                   lhsResp.completeness == rhsResp.completeness &&
                   lhsResp.relevance == rhsResp.relevance &&
                   lhsURL == rhsURL &&
                   lhsRaw == rhsRaw
        case let (.failure(lhsMsg), .failure(rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

struct RecordingPayload: Equatable {
    let fileURL: URL
}

@MainActor
final class RecordingViewModel: ObservableObject {
    @Published var state: EvaluationState = .idle
    @Published var prompt: String
    @Published var lastResp: TextEvalResp?

    let recorder: AudioRecorderService
    private let client: EvalAPIClient

    private var isInternalProcessing = false

    init(recorder: AudioRecorderService, client: EvalAPIClient, initialPrompt: String) {
        self.recorder = recorder
        self.client = client
        self.prompt = initialPrompt
    }

    func toggleRecording() {
        Task {
            if recorder.isRecording {
                recorder.stop()
                if let fileURL = recorder.lastFileURL {
                    state = .ready(RecordingPayload(fileURL: fileURL))
                }
            } else {
                state = .requestingPermission
                if await recorder.requestPermission() {
                    do {
                        try recorder.start()
                        state = .recording
                    } catch {
                        state = .failure("录音启动失败：\(error.localizedDescription)")
                    }
                } else {
                    state = .failure("无麦克风权限")
                }
            }
        }
    }

    func uploadAndSave(context: ModelContext) {
        guard case let .ready(payload) = state, !isInternalProcessing else { return }

        isInternalProcessing = true
        state = .uploading

        Task {
            do {
                let (resp, raw) = try await client.uploadAudio(fileURL: payload.fileURL, prompt: prompt)
                lastResp = resp

                // 计算总分（0-100）
                let score = (resp.fluency + resp.completeness + resp.relevance) / 3.0

                // ✅ 保存到 SwiftData Item（复用）
                let item = Item(timestamp: Date(), prompt: prompt, userText: nil)
                item.isAudio = true
                item.score = score
                item.aiResponse = raw
                item.audioPath = resp.audioUrl ?? payload.fileURL.path // 先用云端，没有就用本地
                context.insert(item)
                try? context.save()

                state = .success(resp, payload.fileURL, raw)
            } catch {
                state = .failure(error.localizedDescription)
            }

            isInternalProcessing = false
        }
    }

    func retry(context: ModelContext) {
        // 重置状态并重新上传
        uploadAndSave(context: context)
    }
}