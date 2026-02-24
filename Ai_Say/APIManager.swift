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

    // MARK: - 认证拦截器
    private lazy var authenticator: Authenticator = {
        Authenticator()
    }()

    private lazy var interceptor: RequestInterceptor = {
        Interceptor(adapters: [authenticator])
    }()

    func uploadAudio(fileURL: URL, prompt: String?) {
        let url = "\(baseURL)/api/eval/audio"

        isLoading = true
        serverMessage = "上传中..."
        evalResult = nil

        EvalAPIClient.afSession.upload(
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
            method: .post,
            interceptor: interceptor
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
        let url = "\(baseURL)/api/eval/text?persona=\(PersonaStore.shared.current.rawValue)"
        
        let req = TextEvalReq(
            deviceId: DeviceIdManager.shared.deviceId,
            prompt: prompt,
            userText: userText,
            expectedKeywords: nil,
            referenceAnswer: nil
        )
        
        isLoading = true
        serverMessage = "评估中..."
        evalResult = nil
        
        let response = await EvalAPIClient.afSession.request(url, method: .post, parameters: req, encoder: JSONParameterEncoder.default, interceptor: interceptor)
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

    // MARK: - Apple登录相关
    func loginWithApple(identityToken: String) async throws -> [String: Any] {
        let url = "\(baseURL)/api/auth/apple"

        let body: [String: Any] = ["identityToken": identityToken]

        isLoading = true
        serverMessage = "正在登录..."

        let response = await EvalAPIClient.afSession.request(url, method: .post, parameters: body, encoding: JSONEncoding.default)
            .serializingData()
            .response

        isLoading = false

        switch response.result {
        case .success(let data):
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    serverMessage = "✅ 登录成功"
                    return json
                } else {
                    throw NSError(domain: "APIManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的JSON响应"])
                }
            } catch {
                serverMessage = "❌ JSON解析失败：\(error.localizedDescription)"
                throw error
            }
        case .failure(let error):
            serverMessage = "❌ 登录失败：\(error.localizedDescription)"
            throw error
        }
    }
}

// MARK: - 认证拦截器
private class Authenticator: RequestAdapter {
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var request = urlRequest
        // 从 UserDefaults 获取 accessToken
        if let token = UserDefaults.standard.string(forKey: "accessToken"), !token.isEmpty {
            request.headers.add(.authorization(bearerToken: token))
        }
        completion(.success(request))
    }
}
