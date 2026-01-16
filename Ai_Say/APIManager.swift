import Foundation
import Alamofire
import Combine

@MainActor
final class APIManager: ObservableObject {
    static let shared = APIManager()

    private let baseURL = AppConfig.baseURL

    @Published var isLoading = false
    @Published var serverMessage: String = "准备就绪"
    @Published var evalResult: TextEvalResp? = nil

    private init() {}

    func uploadAudio(fileURL: URL, prompt: String?) {
        let url = "\(baseURL)/api/eval/audio"

        isLoading = true
        serverMessage = "上传中..."
        evalResult = nil

        AF.upload(
            multipartFormData: { form in
                // ✅ 后端字段名：file
                form.append(fileURL, withName: "file", fileName: "recording.m4a", mimeType: "audio/m4a")

                if let prompt, !prompt.isEmpty {
                    form.append(Data(prompt.utf8), withName: "prompt")
                }
                
                // Add persona
                let persona = PersonaStore.shared.current.rawValue
                form.append(Data(persona.utf8), withName: "persona")
            },
            to: url,
            method: .post
        )
        .uploadProgress { prog in
            Task { @MainActor in
                self.serverMessage = "上传中... \(Int(prog.fractionCompleted * 100))%"
            }
        }
        .responseData { [weak self] resp in
            guard let self else { return }
            let status = resp.response?.statusCode
            let raw = String(data: resp.data ?? Data(), encoding: .utf8) ?? "<empty>"

            Task { @MainActor in
                self.isLoading = false

                guard let status else {
                    self.serverMessage = "❌ 无状态码（ATS/网络问题）"
                    return
                }

                if (200..<300).contains(status) {
                    do {
                        let decoded = try JSONDecoder().decode(TextEvalResp.self, from: resp.data ?? Data())
                        self.evalResult = decoded
                        self.serverMessage = "✅ 上传并评分完成"
                    } catch {
                        self.serverMessage = "❌ 解码失败：\(error.localizedDescription) | \(raw.prefix(120))"
                    }
                } else {
                    self.serverMessage = "❌ HTTP \(status) | \(raw.prefix(160))"
                }
            }
        }
    }

    func evalText(prompt: String, userText: String) async throws -> TextEvalResp {
        let url = "\(baseURL)/api/eval/text"
        
        let req = TextEvalReq(prompt: prompt, userText: userText, expectedKeywords: nil, referenceAnswer: nil, persona: PersonaStore.shared.current.rawValue)
        
        isLoading = true
        serverMessage = "评估中..."
        evalResult = nil
        
        let response = await AF.request(url, method: .post, parameters: req, encoder: JSONParameterEncoder.default)
            .serializingDecodable(TextEvalResp.self)
            .response
        
        isLoading = false
        
        switch response.result {
        case .success(let result):
            evalResult = result
            serverMessage = "✅ 评估完成"
            return result
        case .failure(let error):
            serverMessage = "❌ 评估失败：\(error.localizedDescription)"
            throw error
        }
    }

    // 供播放拼接完整 URL
    func fullAudioURL(from path: String) -> URL? {
        URL(string: "\(baseURL)\(path)")
    }
}
