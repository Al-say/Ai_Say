//
//  Ai_SayApp.swift
//  Ai_Say
//
//  Created by Alsay_Mac on 2026/1/13.
//

import SwiftUI
import SwiftData

@main
struct Ai_SayApp: App {
    @StateObject private var loginViewModel = LoginViewModel()
    
    init() {
        // 清除旧的缓存 URL，确保使用 AppConfig.host 动态构建
        UserDefaults.standard.removeObject(forKey: "custom_base_url")
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(loginViewModel)
        }
        .modelContainer(sharedModelContainer)
    }
}
