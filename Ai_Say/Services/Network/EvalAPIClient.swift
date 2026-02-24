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

    // 动态读取，支持运行时切换服务器
    var baseURL: String { AppConfig.baseURL }

    // ✅ 统一 JSON 解码器：支持 snake_case 转 camelCase
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    // 自定义 Session：支持自签名证书 + 重定向保持 POST 方法
    static let afSession: Session = {
        // ✅ 信任自签名证书（仅用于开发调试）
        let evaluators: [String: ServerTrustEvaluating] = [
            "14.103.177.132": DisabledTrustEvaluator()
        ]
        let trustManager = ServerTrustManager(allHostsMustBeEvaluated: false, evaluators: evaluators)

        // ✅ 自定义重定向处理器：保持原始 HTTP 方法（防止 POST 被改为 GET）
        let redirectHandler = Redirector(behavior: .modify { task, request, response in
            var newRequest = request
            newRequest.httpMethod = task.originalRequest?.httpMethod ?? request.httpMethod
            newRequest.httpBody = task.originalRequest?.httpBody
            return newRequest
        })

        let config = URLSessionConfiguration.af.default
        config.timeoutIntervalForRequest = AppConfig.requestTimeout

        return Session(
            configuration: config,
            serverTrustManager: trustManager,
            redirectHandler: redirectHandler
        )
    }()

    // MARK: - 认证拦截器
    private lazy var authenticator: Authenticator = {
        Authenticator()
    }()

    private lazy var interceptor: RequestInterceptor = {
        Interceptor(adapters: [authenticator])
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

        // ✅ 注入 JWT Token（URLSession 不走 Alamofire 拦截器，需手动添加）
        if let token = UserDefaults.standard.string(forKey: "accessToken"), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

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

        // ✅ 注入 JWT Token（URLSession 不走 Alamofire 拦截器，需手动添加）
        if let token = UserDefaults.standard.string(forKey: "accessToken"), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

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

    /// 用户名/邮箱登录
    /// POST /api/auth/login
    func loginWithUsername(
        usernameOrEmail: String,
        password: String
    ) async throws -> [String: Any] {
        let url = "\(baseURL)\(Endpoints.authLogin)"
        let body: [String: Any] = [
            "username": usernameOrEmail,
            "password": password
        ]

        // 📤 请求日志
        NetworkLogger.logRequest(method: "POST", url: url, body: nil, params: ["body": body])

        return try await withCheckedThrowingContinuation { continuation in
            let startTime = Date()
            Self.afSession.request(url, method: .post, parameters: body, encoding: JSONEncoding.default)
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
                            if let json = try JSONSerialization.jsonObject(with: resp.data ?? Data()) as? [String: Any] {
                                continuation.resume(returning: json)
                            } else {
                                continuation.resume(throwing: EvalAPIError.decodeFailed("无效的JSON响应"))
                            }
                        } catch {
                            continuation.resume(throwing: EvalAPIError.decodeFailed("JSON解析失败：\(error.localizedDescription)"))
                        }
                    }
                }
        }
    }

    /// 用户注册
    /// POST /api/auth/register
    func registerUser(
        username: String,
        email: String,
        password: String
    ) async throws -> [String: Any] {
        let url = "\(baseURL)\(Endpoints.authRegister)"
        let body: [String: Any] = [
            "username": username,
            "email": email,
            "password": password
        ]

        // 📤 请求日志
        NetworkLogger.logRequest(method: "POST", url: url, body: nil, params: ["body": body])

        return try await withCheckedThrowingContinuation { continuation in
            let startTime = Date()
            Self.afSession.request(url, method: .post, parameters: body, encoding: JSONEncoding.default)
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
                            if let json = try JSONSerialization.jsonObject(with: resp.data ?? Data()) as? [String: Any] {
                                continuation.resume(returning: json)
                            } else {
                                continuation.resume(throwing: EvalAPIError.decodeFailed("无效的JSON响应"))
                            }
                        } catch {
                            continuation.resume(throwing: EvalAPIError.decodeFailed("JSON解析失败：\(error.localizedDescription)"))
                        }
                    }
                }
        }
    }

    /// 获取当前用户信息
    /// GET /api/auth/me
    func fetchCurrentUser() async throws -> [String: Any] {
        let url = "\(baseURL)\(Endpoints.authMe)"

        // 📤 请求日志
        NetworkLogger.logRequest(method: "GET", url: url)

        return try await withCheckedThrowingContinuation { continuation in
            let startTime = Date()
            Self.afSession.request(url, method: .get, interceptor: interceptor)
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
                            if let json = try JSONSerialization.jsonObject(with: resp.data ?? Data()) as? [String: Any] {
                                continuation.resume(returning: json)
                            } else {
                                continuation.resume(throwing: EvalAPIError.decodeFailed("无效的JSON响应"))
                            }
                        } catch {
                            continuation.resume(throwing: EvalAPIError.decodeFailed("JSON解析失败：\(error.localizedDescription)"))
                        }
                    }
                }
        }
    }

    /// 绑定设备ID
    /// POST /api/auth/bind-device（后端返回空 Body，仅校验 2xx 状态码）
    func bindDevice(deviceId: String) async throws {
        let url = "\(baseURL)\(Endpoints.authBindDevice)"
        let body: [String: Any] = ["deviceId": deviceId]

        // 📤 请求日志
        NetworkLogger.logRequest(method: "POST", url: url, body: nil, params: ["body": body])

        return try await withCheckedThrowingContinuation { continuation in
            let startTime = Date()
            Self.afSession.request(url, method: .post, parameters: body, encoding: JSONEncoding.default, interceptor: interceptor)
                .validate(statusCode: 200..<300)
                .response { resp in
                    let duration = Date().timeIntervalSince(startTime)
                    let code = resp.response?.statusCode ?? 0

                    // 📥 响应日志
                    NetworkLogger.logResponse(url: url, statusCode: code, data: resp.data, duration: duration)

                    Task { @MainActor in
                        switch resp.result {
                        case .success:
                            print("✅ 设备绑定成功")
                            continuation.resume()
                        case .failure(let error):
                            let raw = String(data: resp.data ?? Data(), encoding: .utf8) ?? "<empty>"
                            continuation.resume(throwing: EvalAPIError.badStatus(code, raw))
                        }
                    }
                }
        }
    }

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
            Self.afSession.request(url, method: .get, parameters: params, interceptor: interceptor)
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
            Self.afSession.request(url, method: .get, parameters: params, interceptor: interceptor)
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
                            let page = try Self.decoder.decode(SpringPage<SceneDTO>.self, from: resp.data ?? Data())
                            continuation.resume(returning: page.content)
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
            Self.afSession.request(url, method: .get, parameters: params, interceptor: interceptor)
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
            Self.afSession.request(url, method: .get, parameters: params, interceptor: interceptor)
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
            Self.afSession.request(url, method: .get, parameters: params, interceptor: interceptor)
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
            Self.afSession.request(url, method: .get, interceptor: interceptor)
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

    /// 获取评估历史记录
    /// GET /api/v1/evaluate/history?page=0&size=20
    func fetchEvaluationHistory(
        page: Int = 0,
        size: Int = 20
    ) async throws -> SpringPage<EvaluationRecordDTO> {
        let url = "\(baseURL)\(Endpoints.evaluateHistory)"
        let params = ["page": "\(page)", "size": "\(size)"]

        // 📤 请求日志
        NetworkLogger.logRequest(method: "GET", url: url, params: params)

        return try await withCheckedThrowingContinuation { continuation in
            let startTime = Date()
            Self.afSession.request(url, method: .get, parameters: params, interceptor: interceptor)
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
                            let page = try Self.decoder.decode(SpringPage<EvaluationRecordDTO>.self, from: resp.data ?? Data())
                            continuation.resume(returning: page)
                        } catch {
                            NetworkLogger.logDecodeError(error, rawData: resp.data, context: "fetchEvaluationHistory")
                            continuation.resume(throwing: EvalAPIError.decodeFailed("EvaluationHistory 解析失败：\(error.localizedDescription)\n\(raw)"))
                        }
                    }
                }
        }
    }

    /// 获取成长统计数据
    /// GET /api/growth/stats
    func fetchGrowthStats() async throws -> GrowthStatsDTO {
        let url = "\(baseURL)\(Endpoints.growthStats)"

        // 📤 请求日志
        NetworkLogger.logRequest(method: "GET", url: url)

        return try await withCheckedThrowingContinuation { continuation in
            let startTime = Date()
            Self.afSession.request(url, method: .get, interceptor: interceptor)
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
                            let stats = try Self.decoder.decode(GrowthStatsDTO.self, from: resp.data ?? Data())
                            continuation.resume(returning: stats)
                        } catch {
                            NetworkLogger.logDecodeError(error, rawData: resp.data, context: "fetchGrowthStats")
                            continuation.resume(throwing: EvalAPIError.decodeFailed("GrowthStats 解析失败：\(error.localizedDescription)\n\(raw)"))
                        }
                    }
                }
        }
    }

    /// 获取单次评估详情
    /// GET /api/growth/{recordId}
    func fetchEvaluationDetail(recordId: String) async throws -> EvaluationDetailDTO {
        let url = "\(baseURL)\(Endpoints.growthDetail)/\(recordId)"

        // 📤 请求日志
        NetworkLogger.logRequest(method: "GET", url: url)

        return try await withCheckedThrowingContinuation { continuation in
            let startTime = Date()
            Self.afSession.request(url, method: .get, interceptor: interceptor)
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
                            let detail = try Self.decoder.decode(EvaluationDetailDTO.self, from: resp.data ?? Data())
                            continuation.resume(returning: detail)
                        } catch {
                            NetworkLogger.logDecodeError(error, rawData: resp.data, context: "fetchEvaluationDetail")
                            continuation.resume(throwing: EvalAPIError.decodeFailed("EvaluationDetail 解析失败：\(error.localizedDescription)\n\(raw)"))
                        }
                    }
                }
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
            print("🔐 Authenticator: Added Authorization header for \(urlRequest.url?.absoluteString ?? "unknown")")
        } else {
            print("⚠️ Authenticator: No token found in UserDefaults for \(urlRequest.url?.absoluteString ?? "unknown")")
        }
        completion(.success(request))
    }
}