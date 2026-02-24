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
        // 设置服务器地址
        AppConfig.baseURL = "http://192.168.0.105:2580"
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
