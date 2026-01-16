# API 对接文档：文本评估接口（iOS 端）

## 0. 配置说明

### BaseURL 配置

所有前端请求统一使用 **8082端口**：

- **模拟器调试**：自动使用 `http://localhost:8082`
- **真机调试**：需配置电脑局域网IP，通过UserDefaults设置：
  ```swift
  UserDefaults.standard.set("192.168.0.104", forKey: "api_host")
  ```
  确保iPad/iPhone与电脑在同一Wi-Fi网络下。

### 支持的API端点

- `/api/eval/text` - 文本评估
- `/api/eval/audio` - 音频评估
- `/api/growth/history` - 成长历史
- `/api/growth/analysis` - 成长分析
- `/api/growth/detail/{id}` - 成长详情
- `/api/home/dashboard` - 首页仪表板
- `/api/explore/scenes` - 探索场景

---

## 1. 功能说明

前端发送题目（prompt）与用户英语文本（userText），后端调用 DeepSeek 进行多维度评分、语法纠错并返回建议；并完成数据库入库。

---

## 2. 接口定义

* **URL**：`http://localhost:8082/api/eval/text`

  * **真机调试**：把 `localhost` 改成电脑局域网 IP（如 `http://192.168.1.5:8082`），并确保手机/电脑同一 Wi-Fi
* **Method**：`POST`
* **Content-Type**：`application/json`

---

## 2. 请求参数（Request Body）

| 字段名              | 类型            | 必填 | 说明                    |
| ---------------- | ------------- | -- | --------------------- |
| prompt           | String        | ✅  | 题目/场景描述               |
| userText         | String        | ✅  | 用户输入回答                |
| expectedKeywords | Array<String> | ❌  | 期望关键词，可 `null` 或 `[]` |
| referenceAnswer  | String        | ❌  | 参考答案，可 `null`         |

请求示例：

```json
{
  "prompt": "Describe your favorite hobby.",
  "userText": "My hobby is play game.",
  "expectedKeywords": null,
  "referenceAnswer": null
}
```

---

## 3. 响应参数（Response Body）

成功响应（HTTP 200）示例（字段名/结构固定）：

```json
{
  "recordId": 2,
  "fluency": 65.0,
  "completeness": 60.0,
  "relevance": 90.0,
  "grammarIssueCount": 3,
  "issues": [
    {
      "offset": 11,
      "length": 4,
      "message": "动词形式错误",
      "replacements": ["playing games"]
    }
  ],
  "suggestions": [
    "扩展回答以提供更多细节",
    "使用更丰富的词汇"
  ],
  "missingKeywords": [],
  "createdAt": "2026-01-13T16:12:40.865"
}
```

---

## 4. iOS 前端接入（SwiftUI + Alamofire）

### 4.1 Models.swift（字段名与后端 1:1 对齐）

> Swift 6 / iOS 26：为避免并发隔离导致的 `Sendable` 编译错误，模型采用 `Sendable + nonisolated Encodable/Decodable`。

```swift
import Foundation

// 1) 请求模型
struct TextEvalReq: Sendable {
    let prompt: String
    let userText: String
    var expectedKeywords: [String]? = nil
    var referenceAnswer: String? = nil
}
nonisolated extension TextEvalReq: Encodable {}

// 2) 响应模型
struct TextEvalResp: Sendable {
    let recordId: Int64?

    let fluency: Double
    let completeness: Double
    let relevance: Double

    let grammarIssueCount: Int?
    let issues: [Issue]?

    let suggestions: [String]?
    let missingKeywords: [String]?

    let createdAt: String?
}
nonisolated extension TextEvalResp: Decodable {}

// 3) Issue 模型
struct Issue: Identifiable, Sendable {
    var id: String { "\(offset)-\(length)-\(message)" }

    let offset: Int
    let length: Int
    let message: String
    let replacements: [String]?
}
nonisolated extension Issue: Decodable {}
```

---

### 4.2 APIManager.swift（Alamofire 调用）

```swift
import Foundation
import Alamofire
import Combine

final class APIManager: ObservableObject {
    static let shared = APIManager()
    private init() {}

    // 模拟器：localhost；真机：改为 Mac 局域网 IP
    private let baseURL = "http://localhost:8082"

    @Published var isLoading = false
    @Published var serverMessage = "准备就绪"
    @Published var evalResult: TextEvalResp? = nil

    func evalText(prompt: String, userText: String) {
        let url = "\(baseURL)/api/eval/text"

        DispatchQueue.main.async {
            self.isLoading = true
            self.serverMessage = "AI 正在评估..."
            self.evalResult = nil
        }

        let reqBody = TextEvalReq(prompt: prompt, userText: userText)

        AF.request(url,
                   method: .post,
                   parameters: reqBody,
                   encoder: JSONParameterEncoder.default)
        .validate(statusCode: 200..<300)
        .responseDecodable(of: TextEvalResp.self) { [weak self] response in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch response.result {
                case .success(let data):
                    self?.evalResult = data
                    self?.serverMessage = "✅ 评分完成"
                    print("✅ 收到数据:", data)
                case .failure(let error):
                    self?.serverMessage = "❌ 请求失败: \(error.localizedDescription)"
                    print("❌ Error:", error)
                }
            }
        }
    }
}
```

---

## 5. 前端展示注意事项

* `issues/suggestions/grammarIssueCount/missingKeywords` 都可能为空：UI 层用 `if let` 或 `?? []` 防空。
* 真机调试必须改 IP，且同一 Wi-Fi。

---

## 6. 联调自检（iOS 侧）

* 模拟器：`localhost:8082` 可直接访问
* 真机：`http://<MacIP>:8082/api/eval/text`
* iPad Safari 先打开 `http://<MacIP>:8082/api/test` 验证网络可达，再跑 App

---