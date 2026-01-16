// Services/Network/EvalAPIClient.swift
import Foundation
import Alamofire

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

    // ✅ 统一 JSON 解码器：支持 snake_case 转 camelCase
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private init() {}

    /// 上传音频并评估（简单版本）
    func uploadAudio(
        fileURL: URL,
        prompt: String?,
        persona: UserPersona,
        timeout: TimeInterval = 60
    ) async throws -> (resp: TextEvalResp, rawJSON: String) {

        let urlString = "\(baseURL)/api/eval/audio"
        guard let url = URL(string: urlString) else {
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
            fileFieldName: "file",
            fileName: "upload.m4a",
            mimeType: "audio/x-m4a",
            prompt: prompt,
            persona: persona
        )

        request.httpBody = body
        request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")

        // 📤 请求日志
        NetworkLogger.logRequest(
            method: "POST",
            url: urlString,
            headers: ["Content-Type": "multipart/form-data"],
            body: nil,  // 不打印二进制文件
            params: ["prompt": prompt ?? "", "persona": persona.rawValue]
        )

        let startTime = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        let duration = Date().timeIntervalSince(startTime)

        let raw = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        // 📥 响应日志
        NetworkLogger.logResponse(url: urlString, statusCode: status, data: data, duration: duration)

        guard (200..<300).contains(status) else {
            throw EvalAPIError.badStatus(status, raw)
        }

        do {
            let decoded = try Self.decoder.decode(TextEvalResp.self, from: data)
            return (decoded, raw)
        } catch {
            NetworkLogger.logDecodeError(error, rawData: data, context: "uploadAudio")
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
    /// POST /api/eval/text?persona=XXX  Body: {deviceId, prompt, userText}
    func evalText(
        prompt: String,
        text: String,
        persona: UserPersona,
        timeout: TimeInterval = 30
    ) async throws -> (resp: TextEvalResp, rawJSON: String) {

        let urlString = "\(baseURL)/api/eval/text?persona=\(persona.rawValue)"
        guard let url = URL(string: urlString) else {
            throw EvalAPIError.invalidURL
        }

        // ✅ Body 包含 deviceId
        let req = TextEvalReq(
            deviceId: DeviceIdManager.shared.deviceId,
            prompt: prompt,
            userText: text,
            expectedKeywords: nil,
            referenceAnswer: nil
        )
        let bodyData = try JSONEncoder().encode(req)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        // 📤 请求日志
        NetworkLogger.logRequest(
            method: "POST",
            url: urlString,
            headers: ["Content-Type": "application/json"],
            body: bodyData
        )

        let startTime = Date()
        let (responseData, response) = try await URLSession.shared.data(for: request)
        let duration = Date().timeIntervalSince(startTime)

        let raw = String(data: responseData, encoding: .utf8) ?? "<non-utf8 body>"
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        // 📥 响应日志
        NetworkLogger.logResponse(url: urlString, statusCode: status, data: responseData, duration: duration)

        guard (200..<300).contains(status) else {
            throw EvalAPIError.badStatus(status, raw)
        }

        do {
            let decoded = try Self.decoder.decode(TextEvalResp.self, from: responseData)
            return (decoded, raw)
        } catch {
            NetworkLogger.logDecodeError(error, rawData: responseData, context: "evalText")
            throw EvalAPIError.decodeFailed("\(error)\nRaw: \(raw)")
        }
    }

    // MARK: - 🆕 完整音频评估（推荐使用）
    /// POST /api/eval/audio/full
    /// Form: deviceId, persona, scene, audio
    func uploadFullAudio(
        fileURL: URL,
        scene: String,
        persona: UserPersona,
        timeout: TimeInterval = 90
    ) async throws -> (resp: TextEvalResp, rawJSON: String) {

        let urlString = "\(baseURL)\(Endpoints.evalAudioFull)"
        guard let url = URL(string: urlString) else {
            throw EvalAPIError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let body = try makeFullAudioMultipartBody(
            boundary: boundary,
            fileURL: fileURL,
            scene: scene,
            persona: persona
        )

        request.httpBody = body
        request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")

        // 📤 请求日志
        NetworkLogger.logRequest(
            method: "POST",
            url: urlString,
            headers: ["Content-Type": "multipart/form-data"],
            params: [
                "deviceId": DeviceIdManager.shared.deviceId,
                "persona": persona.rawValue,
                "scene": scene,
                "audio": fileURL.lastPathComponent
            ]
        )

        let startTime = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        let duration = Date().timeIntervalSince(startTime)

        let raw = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        // 📥 响应日志
        NetworkLogger.logResponse(url: urlString, statusCode: status, data: data, duration: duration)

        guard (200..<300).contains(status) else {
            throw EvalAPIError.badStatus(status, raw)
        }

        do {
            let decoded = try Self.decoder.decode(TextEvalResp.self, from: data)
            return (decoded, raw)
        } catch {
            NetworkLogger.logDecodeError(error, rawData: data, context: "uploadFullAudio")
            throw EvalAPIError.decodeFailed("\(error)\nRaw: \(raw)")
        }
    }

    /// 构建完整音频评估的 Multipart Body
    private func makeFullAudioMultipartBody(
        boundary: String,
        fileURL: URL,
        scene: String,
        persona: UserPersona
    ) throws -> Data {
        var data = Data()

        func appendLine(_ s: String) {
            data.append(s.data(using: .utf8)!)
            data.append("\r\n".data(using: .utf8)!)
        }

        // 1) deviceId
        appendLine("--\(boundary)")
        appendLine("Content-Disposition: form-data; name=\"deviceId\"")
        appendLine("")
        appendLine(DeviceIdManager.shared.deviceId)

        // 2) persona
        appendLine("--\(boundary)")
        appendLine("Content-Disposition: form-data; name=\"persona\"")
        appendLine("")
        appendLine(persona.rawValue)

        // 3) scene
        appendLine("--\(boundary)")
        appendLine("Content-Disposition: form-data; name=\"scene\"")
        appendLine("")
        appendLine(scene)

        // 4) audio file
        let fileData = try Data(contentsOf: fileURL)
        appendLine("--\(boundary)")
        appendLine("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.m4a\"")
        appendLine("Content-Type: audio/x-m4a")
        appendLine("")
        data.append(fileData)
        appendLine("")

        appendLine("--\(boundary)--")
        return data
    }
}

// MARK: - GET 接口
extension EvalAPIClient {

    /// 获取今日挑战
    /// GET /api/home/daily?persona=XXX
    func fetchDailyChallenge(
        persona: UserPersona
    ) async throws -> DailyChallengeDTO {
        let url = "\(baseURL)\(Endpoints.homeDaily)"
        let params = ["persona": persona.rawValue]

        // 📤 请求日志
        NetworkLogger.logRequest(method: "GET", url: url, params: params)

        return try await withCheckedThrowingContinuation { continuation in
            let startTime = Date()
            AF.request(url, method: .get, parameters: params)
                .responseData { resp in
                    let duration = Date().timeIntervalSince(startTime)
                    let code = resp.response?.statusCode ?? 0
                    let raw = String(data: resp.data ?? Data(), encoding: .utf8) ?? "<empty>"

                    // 📥 响应日志
                    NetworkLogger.logResponse(url: url, statusCode: code, data: resp.data, duration: duration)

                    Task { @MainActor in
                        guard (200..<300).contains(code) else {
                            continuation.resume(throwing: EvalAPIError.badStatus(code, raw))
                            return
                        }
                        do {
                            let dto = try Self.decoder.decode(DailyChallengeDTO.self, from: resp.data ?? Data())
                            continuation.resume(returning: dto)
                        } catch {
                            NetworkLogger.logDecodeError(error, rawData: resp.data, context: "fetchDailyChallenge")
                            continuation.resume(throwing: EvalAPIError.decodeFailed("DailyChallenge 解析失败：\(error.localizedDescription)\n\(raw)"))
                        }
                    }
                }
        }
    }

    /// 获取练习场景列表
    /// GET /api/explore/scenes?persona=XXX&category=YYY(可选)
    func fetchScenes(
        persona: UserPersona,
        category: String? = nil
    ) async throws -> [SceneDTO] {
        let url = "\(baseURL)\(Endpoints.exploreScenes)"

        var params: [String: String] = ["persona": persona.rawValue]
        if let category { params["category"] = category }

        // 📤 请求日志
        NetworkLogger.logRequest(method: "GET", url: url, params: params)

        return try await withCheckedThrowingContinuation { continuation in
            let startTime = Date()
            AF.request(url, method: .get, parameters: params)
                .responseData { resp in
                    let duration = Date().timeIntervalSince(startTime)
                    let code = resp.response?.statusCode ?? 0
                    let raw = String(data: resp.data ?? Data(), encoding: .utf8) ?? "<empty>"

                    // 📥 响应日志
                    NetworkLogger.logResponse(url: url, statusCode: code, data: resp.data, duration: duration)

                    Task { @MainActor in
                        guard (200..<300).contains(code) else {
                            continuation.resume(throwing: EvalAPIError.badStatus(code, raw))
                            return
                        }
                        do {
                            let list = try Self.decoder.decode([SceneDTO].self, from: resp.data ?? Data())
                            continuation.resume(returning: list)
                        } catch {
                            NetworkLogger.logDecodeError(error, rawData: resp.data, context: "fetchScenes")
                            continuation.resume(throwing: EvalAPIError.decodeFailed("Scenes 解析失败：\(error.localizedDescription)\n\(raw)"))
                        }
                    }
                }
        }
    }
}

// MARK: - Growth API (成长模块)
extension EvalAPIClient {

    /// 获取评估历史 (趋势图数据)
    /// GET /api/growth/history?deviceId=XXX&persona=YYY&limit=ZZZ
    func fetchGrowthHistory(
        persona: UserPersona,
        limit: Int = 50
    ) async throws -> [GrowthHistoryItem] {
        let url = "\(baseURL)\(Endpoints.growthHistory)"
        let params: [String: Any] = [
            "deviceId": DeviceIdManager.shared.deviceId,
            "persona": persona.rawValue,
            "limit": limit
        ]

        // 📤 请求日志
        NetworkLogger.logRequest(method: "GET", url: url, params: params)

        return try await withCheckedThrowingContinuation { continuation in
            let startTime = Date()
            AF.request(url, method: .get, parameters: params)
                .responseData { resp in
                    let duration = Date().timeIntervalSince(startTime)
                    let code = resp.response?.statusCode ?? 0
                    let raw = String(data: resp.data ?? Data(), encoding: .utf8) ?? "<empty>"

                    // 📥 响应日志
                    NetworkLogger.logResponse(url: url, statusCode: code, data: resp.data, duration: duration)

                    Task { @MainActor in
                        guard (200..<300).contains(code) else {
                            continuation.resume(throwing: EvalAPIError.badStatus(code, raw))
                            return
                        }
                        do {
                            let items = try Self.decoder.decode([GrowthHistoryItem].self, from: resp.data ?? Data())
                            continuation.resume(returning: items)
                        } catch {
                            NetworkLogger.logDecodeError(error, rawData: resp.data, context: "fetchGrowthHistory")
                            continuation.resume(throwing: EvalAPIError.decodeFailed("GrowthHistory 解析失败：\(error.localizedDescription)\n\(raw)"))
                        }
                    }
                }
        }
    }

    /// 获取雷达图分析 (90天)
    /// GET /api/growth/analysis?deviceId=XXX&persona=YYY
    func fetchGrowthAnalysis(
        persona: UserPersona
    ) async throws -> GrowthAnalysisDTO {
        let url = "\(baseURL)\(Endpoints.growthAnalysis)"
        let params: [String: String] = [
            "deviceId": DeviceIdManager.shared.deviceId,
            "persona": persona.rawValue
        ]

        // 📤 请求日志
        NetworkLogger.logRequest(method: "GET", url: url, params: params)

        return try await withCheckedThrowingContinuation { continuation in
            let startTime = Date()
            AF.request(url, method: .get, parameters: params)
                .responseData { resp in
                    let duration = Date().timeIntervalSince(startTime)
                    let code = resp.response?.statusCode ?? 0
                    let raw = String(data: resp.data ?? Data(), encoding: .utf8) ?? "<empty>"

                    // 📥 响应日志
                    NetworkLogger.logResponse(url: url, statusCode: code, data: resp.data, duration: duration)

                    Task { @MainActor in
                        guard (200..<300).contains(code) else {
                            continuation.resume(throwing: EvalAPIError.badStatus(code, raw))
                            return
                        }
                        do {
                            let dto = try Self.decoder.decode(GrowthAnalysisDTO.self, from: resp.data ?? Data())
                            continuation.resume(returning: dto)
                        } catch {
                            NetworkLogger.logDecodeError(error, rawData: resp.data, context: "fetchGrowthAnalysis")
                            continuation.resume(throwing: EvalAPIError.decodeFailed("GrowthAnalysis 解析失败：\(error.localizedDescription)\n\(raw)"))
                        }
                    }
                }
        }
    }

    /// 获取单条评估详情
    /// GET /api/growth/detail/{id}?deviceId=XXX
    func fetchGrowthDetail(
        id: Int64
    ) async throws -> GrowthDetailDTO {
        let url = "\(baseURL)\(Endpoints.growthDetail)/\(id)"
        let params: [String: String] = [
            "deviceId": DeviceIdManager.shared.deviceId
        ]

        // 📤 请求日志
        NetworkLogger.logRequest(method: "GET", url: url, params: params)

        return try await withCheckedThrowingContinuation { continuation in
            let startTime = Date()
            AF.request(url, method: .get, parameters: params)
                .responseData { resp in
                    let duration = Date().timeIntervalSince(startTime)
                    let code = resp.response?.statusCode ?? 0
                    let raw = String(data: resp.data ?? Data(), encoding: .utf8) ?? "<empty>"

                    // 📥 响应日志
                    NetworkLogger.logResponse(url: url, statusCode: code, data: resp.data, duration: duration)

                    Task { @MainActor in
                        guard (200..<300).contains(code) else {
                            continuation.resume(throwing: EvalAPIError.badStatus(code, raw))
                            return
                        }
                        do {
                            let dto = try Self.decoder.decode(GrowthDetailDTO.self, from: resp.data ?? Data())
                            continuation.resume(returning: dto)
                        } catch {
                            NetworkLogger.logDecodeError(error, rawData: resp.data, context: "fetchGrowthDetail")
                            continuation.resume(throwing: EvalAPIError.decodeFailed("GrowthDetail 解析失败：\(error.localizedDescription)\n\(raw)"))
                        }
                    }
                }
        }
    }
}

// MARK: - Profile API (个人中心)
extension EvalAPIClient {

    /// 获取用户统计
    /// GET /api/profile/stats?deviceId=XXX
    func fetchProfileStats() async throws -> ProfileStatsDTO {
        let url = "\(baseURL)\(Endpoints.profileStats)"
        let params: [String: String] = [
            "deviceId": DeviceIdManager.shared.deviceId
        ]

        // 📤 请求日志
        NetworkLogger.logRequest(method: "GET", url: url, params: params)

        return try await withCheckedThrowingContinuation { continuation in
            let startTime = Date()
            AF.request(url, method: .get, parameters: params)
                .responseData { resp in
                    let duration = Date().timeIntervalSince(startTime)
                    let code = resp.response?.statusCode ?? 0
                    let raw = String(data: resp.data ?? Data(), encoding: .utf8) ?? "<empty>"

                    // 📥 响应日志
                    NetworkLogger.logResponse(url: url, statusCode: code, data: resp.data, duration: duration)

                    Task { @MainActor in
                        guard (200..<300).contains(code) else {
                            continuation.resume(throwing: EvalAPIError.badStatus(code, raw))
                            return
                        }
                        do {
                            let dto = try Self.decoder.decode(ProfileStatsDTO.self, from: resp.data ?? Data())
                            continuation.resume(returning: dto)
                        } catch {
                            NetworkLogger.logDecodeError(error, rawData: resp.data, context: "fetchProfileStats")
                            continuation.resume(throwing: EvalAPIError.decodeFailed("ProfileStats 解析失败：\(error.localizedDescription)\n\(raw)"))
                        }
                    }
                }
        }
    }

    /// 获取个人中心模块信息
    /// GET /api/profile
    func fetchProfile() async throws -> ProfileDTO {
        let url = "\(baseURL)\(Endpoints.profile)"

        // 📤 请求日志
        NetworkLogger.logRequest(method: "GET", url: url)

        return try await withCheckedThrowingContinuation { continuation in
            let startTime = Date()
            AF.request(url, method: .get)
                .responseData { resp in
                    let duration = Date().timeIntervalSince(startTime)
                    let code = resp.response?.statusCode ?? 0
                    let raw = String(data: resp.data ?? Data(), encoding: .utf8) ?? "<empty>"

                    // 📥 响应日志
                    NetworkLogger.logResponse(url: url, statusCode: code, data: resp.data, duration: duration)

                    Task { @MainActor in
                        guard (200..<300).contains(code) else {
                            continuation.resume(throwing: EvalAPIError.badStatus(code, raw))
                            return
                        }
                        do {
                            let dto = try Self.decoder.decode(ProfileDTO.self, from: resp.data ?? Data())
                            continuation.resume(returning: dto)
                        } catch {
                            NetworkLogger.logDecodeError(error, rawData: resp.data, context: "fetchProfile")
                            continuation.resume(throwing: EvalAPIError.decodeFailed("Profile 解析失败：\(error.localizedDescription)\n\(raw)"))
                        }
                    }
                }
        }
    }
}