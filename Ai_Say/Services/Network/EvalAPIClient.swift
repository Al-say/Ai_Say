// Services/Network/EvalAPIClient.swift
import Foundation

enum EvalAPIError: Error, LocalizedError {
    case invalidURL
    case badStatus(Int, String)
    case decodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL 无效"
        case .badStatus(let code, let body): return "服务器错误(\(code)): \(body)"
        case .decodeFailed(let msg): return "解析失败: \(msg)"
        }
    }
}

final class EvalAPIClient: Sendable {
    static let shared = EvalAPIClient()

    // ✅ 真机必须用 Mac 局域网 IP
    let baseURL = AppConfig.baseURL

    private init() {}

    /// 上传音频并评估（返回：强类型 + 原始 JSON 字符串）
    func uploadAudio(
        fileURL: URL,
        prompt: String?,
        persona: UserPersona,
        timeout: TimeInterval = 60
    ) async throws -> (resp: TextEvalResp, rawJSON: String) {

        guard let url = URL(string: "\(baseURL)/api/eval/audio") else {
            throw EvalAPIError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let body = try makeMultipartBody(
            boundary: boundary,
            fileURL: fileURL,
            fileFieldName: "file",              // ✅ 后端要求：file
            fileName: "upload.m4a",
            mimeType: "audio/x-m4a",
            prompt: prompt,
            persona: persona
        )

        request.httpBody = body
        request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")

        let (data, response) = try await URLSession.shared.data(for: request)

        let raw = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard (200..<300).contains(status) else {
            throw EvalAPIError.badStatus(status, raw)
        }

        do {
            let decoded = try JSONDecoder().decode(TextEvalResp.self, from: data)
            return (decoded, raw)
        } catch {
            throw EvalAPIError.decodeFailed("\(error)\nRaw: \(raw)")
        }
    }

    func fullAudioURL(from audioUrl: String) -> URL? {
        if audioUrl.hasPrefix("http") { return URL(string: audioUrl) }
        return URL(string: "\(baseURL)\(audioUrl)")
    }

    private func makeMultipartBody(
        boundary: String,
        fileURL: URL,
        fileFieldName: String,
        fileName: String,
        mimeType: String,
        prompt: String?,
        persona: UserPersona
    ) throws -> Data {
        var data = Data()

        func appendLine(_ s: String) {
            data.append(s.data(using: .utf8)!)
            data.append("\r\n".data(using: .utf8)!)
        }

        // 1) file
        let fileData = try Data(contentsOf: fileURL)
        appendLine("--\(boundary)")
        appendLine("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(fileName)\"")
        appendLine("Content-Type: \(mimeType)")
        appendLine("")
        data.append(fileData)
        appendLine("")

        // 2) prompt（可选）
        if let prompt, !prompt.isEmpty {
            appendLine("--\(boundary)")
            appendLine("Content-Disposition: form-data; name=\"prompt\"")
            appendLine("")
            appendLine(prompt)
        }

        // 3) persona
        appendLine("--\(boundary)")
        appendLine("Content-Disposition: form-data; name=\"persona\"")
        appendLine("")
        appendLine(persona.rawValue)

        appendLine("--\(boundary)--")
        return data
    }

    /// 构造完整的 URL
    func fullURL(path: String) -> URL? {
        return URL(string: "\(baseURL)\(path)")
    }

    /// 文本评估
    func evalText(
        prompt: String,
        text: String,
        persona: UserPersona,
        timeout: TimeInterval = 30
    ) async throws -> (resp: TextEvalResp, rawJSON: String) {

        guard let url = URL(string: "\(baseURL)/api/eval/text") else {
            throw EvalAPIError.invalidURL
        }

        let req = TextEvalReq(prompt: prompt, userText: text, expectedKeywords: nil, referenceAnswer: nil, persona: persona.rawValue)
        let data = try JSONEncoder().encode(req)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: request)

        let raw = String(data: responseData, encoding: .utf8) ?? "<non-utf8 body>"
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard (200..<300).contains(status) else {
            throw EvalAPIError.badStatus(status, raw)
        }

        do {
            let decoded = try JSONDecoder().decode(TextEvalResp.self, from: responseData)
            return (decoded, raw)
        } catch {
            throw EvalAPIError.decodeFailed("\(error)\nRaw: \(raw)")
        }
    }
}

// MARK: - 新增 GET 接口
extension EvalAPIClient {

    func fetchDailyChallenge(
        persona: UserPersona,
        completion: @escaping @MainActor (Result<DailyChallengeDTO, String>) -> Void
    ) {
        let url = "\(baseURL)/api/home/daily-challenge"

        AF.request(url, method: .get, parameters: ["persona": persona.rawValue])
            .responseData { resp in
                let code = resp.response?.statusCode ?? 0
                let raw = String(data: resp.data ?? Data(), encoding: .utf8) ?? "<empty>"

                Task { @MainActor in
                    guard (200..<300).contains(code) else {
                        completion(.failure("DailyChallenge 请求失败(\(code))：\(raw)"))
                        return
                    }
                    do {
                        let dto = try JSONDecoder().decode(DailyChallengeDTO.self, from: resp.data ?? Data())
                        completion(.success(dto))
                    } catch {
                        completion(.failure("DailyChallenge 解析失败：\(error.localizedDescription)\n\(raw)"))
                    }
                }
            }
    }

    func fetchScenes(
        persona: UserPersona,
        completion: @escaping @MainActor (Result<[SceneDTO], String>) -> Void
    ) {
        let url = "\(baseURL)/api/explore/scenes"

        AF.request(url, method: .get, parameters: ["persona": persona.rawValue])
            .responseData { resp in
                let code = resp.response?.statusCode ?? 0
                let raw = String(data: resp.data ?? Data(), encoding: .utf8) ?? "<empty>"

                Task { @MainActor in
                    guard (200..<300).contains(code) else {
                        completion(.failure("Scenes 请求失败(\(code))：\(raw)"))
                        return
                    }
                    do {
                        let list = try JSONDecoder().decode([SceneDTO].self, from: resp.data ?? Data())
                        completion(.success(list))
                    } catch {
                        completion(.failure("Scenes 解析失败：\(error.localizedDescription)\n\(raw)"))
                    }
                }
            }
    }
}