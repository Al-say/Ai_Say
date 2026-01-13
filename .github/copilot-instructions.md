# AI Coding Agent Instructions for Ai_Say

## Architecture Overview
Ai_Say is a SwiftUI iOS app for AI-powered text evaluation. It integrates with a backend API for text analysis and uses SwiftData for local data persistence.

- **Main Components**:
  - `Ai_SayApp.swift`: App entry point with SwiftData setup
  - `RootView.swift`: Navigation root
  - `ContentView.swift`, `TextEvalView.swift`, `SingleShotEvalView.swift`: UI views
  - `APIManager.swift`: Network layer using Alamofire
  - `Models.swift`: Data models (TextEvalReq, TextEvalResp, etc.)
  - `Item.swift`: SwiftData model for local storage

- **Data Flow**: User input in views → APIManager sends requests to backend (localhost:8082/api/eval/text) → Parse TextEvalResp → Update UI

## Key Patterns
- **Concurrency**: Use `Sendable` for all data models to ensure thread safety in Swift 6
- **Alamofire Integration**: For Encodable structs used in API requests, declare as `nonisolated` to avoid MainActor isolation issues. Example:
  ```swift
  nonisolated struct TextEvalReq: Sendable {
      let prompt: String
      let userText: String
      let expectedKeywords: [String]?
      let referenceAnswer: String?
  }
  nonisolated extension TextEvalReq: Encodable {}
  ```
- **API Calls**: Use `AF.request` with `JSONParameterEncoder.default` for POST requests
- **Local Storage**: Use SwiftData with `@Model` for persistent data (e.g., Item)

## Developer Workflows
- **Build**: Open `Ai_Say.xcodeproj` in Xcode, select target and build
- **Run**: Use Xcode simulator or device
- **Test**: Run `Ai_SayTests` and `Ai_SayUITests` from Xcode
- **Debug**: Backend runs on localhost:8082; check `APIManager.baseURL`

## Conventions
- Comments reference corresponding Java backend classes (e.g., `// 对应 Java: EvalDTO.TextEvalReq`)
- Use `let` for immutable model properties
- ObservableObject for state management (e.g., APIManager)

## Integration Points
- Backend API: HTTP POST to /api/eval/text with TextEvalReq, returns TextEvalResp
- Dependencies: Alamofire for networking, SwiftData for persistence

Reference: `Models.swift` for data structures, `APIManager.swift` for API patterns.