import SwiftUI

struct RootView: View {
    @EnvironmentObject private var loginViewModel: LoginViewModel
    
    var body: some View {
        Group {
            if loginViewModel.isCheckingAuth {
                // 显示检查认证状态的界面
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("正在验证登录状态...")
                        .foregroundColor(.secondary)
                }
            } else if loginViewModel.isLoggedIn {
                // 已登录，显示主界面
                MainTabView()
            } else {
                // 未登录，显示登录界面
                LoginView()
                    .environmentObject(loginViewModel)
            }
        }
        .onAppear {
            // 应用启动时检查登录状态
            loginViewModel.checkLoginStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("Logout"))) { _ in
            // 收到退出登录通知，重新检查登录状态
            loginViewModel.checkLoginStatus()
        }
    }
}
