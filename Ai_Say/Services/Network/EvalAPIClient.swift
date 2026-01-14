// Services/Network/EvalAPIClient.swift
import Foundation
import Alamofire

final class EvalAPIClient {
    static let shared = EvalAPIClient()

    private let baseURL = AppConfig.baseURL
    private init() {}

    struct UploadOutput {
        let resp: TextEvalResp
        let rawBody: String
    }

    func uploadAudio(
        fileURL: URL,
        prompt: String?,
        progress: ((Double) -> Void)? = nil,
        completion: @escaping @MainActor (Result<UploadOutput, Error>) -> Void
    ) {
        let url = "\(baseURL)/api/eval/audio"

        let req = AF.upload(
            multipartFormData: { form in
                // 字段名必须是 file
                form.append(fileURL, withName: "file", fileName: "upload.m4a", mimeType: "audio/x-m4a")
                if let prompt, !prompt.isEmpty {
                    form.append(Data(prompt.utf8), withName: "prompt")
                }
            },
            to: url,
            method: .post
        )

        req.uploadProgress { p in
            progress?(p.fractionCompleted)
        }

        req.responseData { resp in
            let statusCode = resp.response?.statusCode ?? 0
            let rawBody = String(data: resp.data ?? Data(), encoding: .utf8) ?? "<empty>"

            Task { @MainActor in
                // 记录到DebugStore
                DebugStore.shared.push(
                    endpoint: url,
                    status: statusCode,
                    raw: rawBody,
                    error: (200..<300).contains(statusCode) ? nil : "Server Error"
                )

                print("📡 Status:", statusCode)
                if (200..<300).contains(statusCode) {
                    do {
                        let decoded = try JSONDecoder().decode(TextEvalResp.self, from: resp.data ?? Data())
                        completion(.success(.init(resp: decoded, rawBody: rawBody)))
                    } catch {
                        print("❌ Decode Error:", error)
                        print("📦 Raw Body:", rawBody)
                        completion(.failure(error))
                    }
                } else {
                    print("❌ Server Body:", rawBody)
                    completion(.failure(NSError(domain: "ServerError", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "服务器错误(\(statusCode))：\(rawBody.prefix(200))"])))
                }
            }
        }
    }

    func fullURL(path: String) -> URL? {
        if path.hasPrefix("http") { return URL(string: path) }
        return URL(string: "\(baseURL)\(path)")
    }
}