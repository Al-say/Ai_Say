import Foundation
import Alamofire
import Combine

final class APIManager: ObservableObject {
    static let shared = APIManager()
    private init() {}

    private let baseURL = "http://192.168.0.104:8082"

    @Published var isLoading = false
    @Published var serverMessage: String = "等待连接..."
    @Published var evalResult: TextEvalResp? = nil

    func checkHealth() {
        let url = "\(baseURL)/api/test"
        DispatchQueue.main.async { self.serverMessage = "请求中..." }

        AF.request(url)
            .responseString { [weak self] resp in
                DispatchQueue.main.async {
                    switch resp.result {
                    case .success(let value):
                        self?.serverMessage = "✅ \(value)"
                    case .failure(let error):
                        self?.serverMessage = "❌ \(error.localizedDescription)"
                    }
                }
            }
    }

    func evalText(prompt: String, userText: String) {
        let url = "\(baseURL)/api/eval/text"
        let reqBody = TextEvalReq(
            prompt: prompt,
            userText: userText,
            expectedKeywords: nil,
            referenceAnswer: nil
        )

        print("REQ URL:", url)

        AF.request(url, method: .post, parameters: reqBody, encoder: JSONParameterEncoder.default)
            .responseData { resp in
                let status = resp.response?.statusCode
                let raw = String(data: resp.data ?? Data(), encoding: .utf8) ?? "<empty>"

                print("STATUS:", status as Any)
                print("RAW:", raw)
                print("ERR:", resp.error as Any)

                DispatchQueue.main.async {
                    if let status, (200..<300).contains(status) {
                        do {
                            let decoded = try JSONDecoder().decode(TextEvalResp.self, from: resp.data ?? Data())
                            self.evalResult = decoded
                            self.serverMessage = "✅ 评分完成"
                        } catch {
                            self.serverMessage = "❌ 解析失败：\(error.localizedDescription)"
                        }
                    } else {
                        self.serverMessage = "❌ HTTP失败：\(status.map(String.init) ?? "nil")"
                    }
                }
            }
    }
}