# AI说话评估后端API接口总览

## 🔐 认证模块 (/api/auth)
- **POST /api/auth/apple** - Apple ID登录认证
- **GET /api/auth/me** - 获取当前用户信息
- **POST /api/auth/bind-device** - 绑定设备ID

## 🏠 主页模块 (/api/home)
- **GET /api/home/daily?persona=EXAM_PREP** - 获取每日挑战题目
  - 参数: persona (EXAM_PREP/CAREER_GROWTH)

## 🔍 探索模块 (/api/explore)
- **GET /api/explore/scenes?persona=EXAM_PREP&category=IELTS&page=0&size=10** - 获取场景列表
  - 参数: persona, category (可选), 分页参数

## 🎯 评估模块 (/api/v1/evaluate)
- **POST /api/v1/evaluate** - 提交语音评估任务
  - Body: {"transcript": "...", "persona": "EXAM_PREP", "scene": "..."}
- **GET /api/v1/evaluate/{taskId}** - 查询评估任务状态
- **GET /api/v1/evaluate/history** - 获取用户评估历史

## 📊 成长模块 (/api/growth)
- **GET /api/growth/history?page=0&size=20** - 获取练习历史记录
- **GET /api/growth/stats** - 获取能力分析统计数据
- **GET /api/growth/{recordId}** - 获取单次评估详情

## 👤 个人中心 (/api/profile)
- **GET /api/profile** - 获取个人主页信息
- **GET /api/profile/stats** - 获取用户统计数据

## 🎵 音频模块 (/api/audio)
- **POST /api/audio/upload** - 上传音频文件进行处理
  - FormData: file (音频文件)

## 🔧 系统模块
- **GET /actuator/health** - 健康检查
- **GET /h2-console** - H2数据库控制台 (开发环境)

## 📋 支持的用户画像 (Persona)
- **EXAM_PREP** - 备考党
- **CAREER_GROWTH** - 职场人

## 🔑 认证方式
- JWT Bearer Token (通过 /api/auth/apple 获取)
- Apple ID集成认证

## 🌐 服务器配置
- **本地开发**: http://localhost:2581
- **生产环境**: http://115.191.38.164:2581

所有接口都支持CORS跨域请求，并包含完整的错误处理和响应格式化。

---

# API 对接文档：文本评估接口（iOS 端）

## 0. 配置说明

### BaseURL 配置

所有前端请求统一使用 **2581端口**：

- **模拟器调试**：设置 `UserDefaults` 的 `api_host` 为 `"115.191.38.164"`
  ```swift
  UserDefaults.standard.set("115.191.38.164", forKey: "api_host")
  ```
- **真机调试**：设置 `UserDefaults` 的 `api_host` 为服务器IP
  ```swift
  UserDefaults.standard.set("115.191.38.164", forKey: "api_host")  // 生产服务器IP
  ```
  确保设备与服务器网络连通。

**重要**：后端已部署到生产服务器 `115.191.38.164:2581`！

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

* **URL**：`http://115.191.38.164:2581/api/eval/text`

  * **生产环境**：使用服务器IP `http://115.191.38.164:2581`
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

    // 生产环境：服务器IP
    private let baseURL = "http://115.191.38.164:2581"

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

* 模拟器/真机：`http://115.191.38.164:2581` 可直接访问
* Safari 先打开 `http://115.191.38.164:2581/api/test` 验证网络可达，再跑 App

---