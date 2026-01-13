import Foundation
import Alamofire
import Combine

final class APIManager: ObservableObject {
    static let shared = APIManager()
    private init() {}

    private let baseURL = "http://localhost:8082"

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
        DispatchQueue.main.async {
            self.isLoading = true
            self.serverMessage = "AI 正在评估..."
            self.evalResult = nil
        }

        let body = TextEvalReq(
            prompt: prompt,
            userText: userText,
            expectedKeywords: nil,
            referenceAnswer: nil
        )

        AF.request(url,
                   method: .post,
                   parameters: body,
                   encoder: JSONParameterEncoder.default)
        .responseDecodable(of: TextEvalResp.self) { [weak self] response in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch response.result {
                case .success(let data):
                    self?.evalResult = data
                    self?.serverMessage = "✅ 评分完成"
                    print("收到数据: \(data)")
                case .failure(let error):
                    self?.serverMessage = "❌ 请求失败: \(error.localizedDescription)"
                    print("Error:", error)
                }
            }
        }
    }
}