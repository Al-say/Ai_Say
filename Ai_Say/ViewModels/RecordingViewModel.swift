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
                let (resp, raw) = try await client.uploadAudio(fileURL: payload.fileURL, prompt: prompt, persona: PersonaStore.shared.current)
                lastResp = resp

                // ✅ 使用统一保存逻辑
                persistEval(resp: resp, prompt: prompt, isAudio: true, audioPath: payload.fileURL.path, rawJSON: raw, context: context)

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

    // ✅ 统一保存逻辑（录音/文本共用）
    @MainActor
    func persistEval(resp: TextEvalResp,
                     prompt: String,
                     isAudio: Bool,
                     audioPath: String?,
                     rawJSON: String,
                     context: ModelContext) {
        let item = Item(timestamp: Date(), prompt: prompt, userText: resp.userText)

        // createdAt -> timestamp
        if let createdAt = resp.createdAt,
           let dt = ISO8601DateFormatter().date(from: createdAt) {
            item.timestamp = dt
        }

        // score 优先 overallScore
        let computed = (resp.fluency + resp.completeness + resp.relevance) / 3.0
        item.score = resp.overallScore ?? computed

        item.isAudio = isAudio
        item.audioPath = audioPath ?? resp.audioUrl
        item.aiResponse = rawJSON

        context.insert(item)
        try? context.save()
    }
}