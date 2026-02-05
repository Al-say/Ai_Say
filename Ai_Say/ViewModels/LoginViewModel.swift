import SwiftUI
import AuthenticationServices
import CryptoKit
import Combine
import Foundation

class LoginViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var loadingMessage = ""
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var isLoggedIn = false
    @Published var isCheckingAuth = false  // 新增：正在检查认证状态
    
    // 用户名/邮箱登录相关
    @Published var usernameOrEmail = ""
    @Published var password = ""
    @Published var isRegisterMode = false  // 切换登录/注册模式
    @Published var confirmPassword = ""  // 注册时确认密码
    
    // 注册专用字段
    @Published var registerUsername = ""
    @Published var registerEmail = ""

    private var currentNonce: String?
    private var authorizationController: ASAuthorizationController?
    
    // 退出登录
    func logout() {
        // 清除所有登录相关数据
        UserDefaults.standard.removeObject(forKey: "accessToken")
        UserDefaults.standard.removeObject(forKey: "loginMode")
        
        // 重置状态
        isLoggedIn = false
        isCheckingAuth = false
        isLoading = false
        
        // 清空表单
        usernameOrEmail = ""
        password = ""
        confirmPassword = ""
        registerUsername = ""
        registerEmail = ""
        
        print("👋 已退出登录")
    }

    // 检查是否已登录
    func checkLoginStatus() {
        // 首先检查是否是游客模式
        if let loginMode = UserDefaults.standard.string(forKey: "loginMode"), loginMode == "guest" {
            print("👤 发现游客登录模式，直接进入主界面")
            isCheckingAuth = false
            isLoggedIn = true
            return
        }

        if let token = UserDefaults.standard.string(forKey: "accessToken"), !token.isEmpty, token != "guest_token" {
            // 🚀 步骤 1: 发现有保存的 Token，先验证它是否有效
            print("🔍 发现保存的 Token，正在验证有效性...")
            isCheckingAuth = true
            Task {
                await validateTokenAndProceed()
            }
        } else {
            // 没有 Token，需要登录
            print("❌ 没有找到 Token，需要登录")
            isCheckingAuth = false
            isLoggedIn = false
        }
    }

    // 验证 Token 并决定下一步
    private func validateTokenAndProceed() async {
        do {
            // 🔥 关键：用一个轻量级的 API 调用来验证 Token
            let _ = try await EvalAPIClient.shared.fetchDailyChallenge(persona: .examPrep)
            await MainActor.run {
                print("✅ Token 验证成功，直接进入主界面")
                isCheckingAuth = false
                isLoggedIn = true
            }
        } catch {
            await MainActor.run {
                print("⚠️ Token 验证失败: \(error.localizedDescription)，需要重新登录")
                // 清除无效 Token
                UserDefaults.standard.removeObject(forKey: "accessToken")
                isCheckingAuth = false
                isLoggedIn = false
            }
        }
    }
    // 游客登录
    func loginAsGuest() {
        // 设置游客模式
        UserDefaults.standard.set("guest", forKey: "loginMode")
        UserDefaults.standard.set("guest_token", forKey: "accessToken") // 虚拟token
        isLoggedIn = true
        print("👤 游客登录成功")
    }
    
    // 用户名/邮箱登录
    func loginWithCredentials() async {
        guard !usernameOrEmail.isEmpty, !password.isEmpty else {
            await MainActor.run {
                showError(message: "请输入用户名/邮箱和密码")
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            loadingMessage = "正在登录..."
        }
        
        do {
            let token = try await EvalAPIClient.shared.loginWithUsername(
                usernameOrEmail: usernameOrEmail,
                password: password
            )
            
            await MainActor.run {
                // 从响应中提取 accessToken 字符串
                if let accessToken = token["accessToken"] as? String {
                    UserDefaults.standard.set(accessToken, forKey: "accessToken")
                    UserDefaults.standard.removeObject(forKey: "loginMode") // 清除游客模式标记
                    isLoggedIn = true
                    isLoading = false
                    loadingMessage = "登录成功"
                    print("✅ 用户名/邮箱登录成功")
                } else {
                    isLoading = false
                    showError(message: "后端响应中没有accessToken")
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                showError(message: "登录失败：\(error.localizedDescription)")
            }
        }
    }
    
    // 用户注册
    func register() async {
        guard !registerUsername.isEmpty, !registerEmail.isEmpty, !password.isEmpty else {
            await MainActor.run {
                showError(message: "请输入用户名、邮箱和密码")
            }
            return
        }
        
        // 验证邮箱格式
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        guard emailPredicate.evaluate(with: registerEmail) else {
            await MainActor.run {
                showError(message: "请输入有效的邮箱地址")
            }
            return
        }
        
        guard password == confirmPassword else {
            await MainActor.run {
                showError(message: "两次输入的密码不一致")
            }
            return
        }
        
        guard password.count >= 6 else {
            await MainActor.run {
                showError(message: "密码长度至少为6位")
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            loadingMessage = "正在注册..."
        }
        
        do {
            let response = try await EvalAPIClient.shared.registerUser(
                username: registerUsername,
                email: registerEmail,
                password: password
            )
            
            await MainActor.run {
                // 注册成功后，尝试从响应中提取token
                if let token = response["accessToken"] as? String {
                    UserDefaults.standard.set(token, forKey: "accessToken")
                    UserDefaults.standard.removeObject(forKey: "loginMode")
                    isLoggedIn = true
                    isLoading = false
                    loadingMessage = "注册成功"
                    print("✅ 用户注册成功")
                } else {
                    // 如果没有返回token，切换到登录模式让用户重新登录
                    isRegisterMode = false
                    isLoading = false
                    showError(message: "注册成功！请使用您的账号登录")
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                showError(message: "注册失败：\(error.localizedDescription)")
            }
        }
    }

    // 处理Apple登录请求
    func handleSignInWithAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    // 处理Apple登录完成
    func handleSignInWithAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                guard let identityToken = appleIDCredential.identityToken,
                      let tokenString = String(data: identityToken, encoding: .utf8) else {
                    showError(message: "无法获取Apple身份令牌")
                    return
                }

                // 发送token到后端
                Task {
                    await loginWithBackend(token: tokenString)
                }
            }
        case .failure(let error):
            showError(message: "Apple登录失败：\(error.localizedDescription)")
        }
    }

    // 向后端发送token
    private func loginWithBackend(token: String) async {
        await MainActor.run {
            isLoading = true
            loadingMessage = "正在登录..."
        }

        do {
            let response = try await APIManager.shared.loginWithApple(identityToken: token)

            await MainActor.run {
                isLoading = false

                // 检查响应中是否有accessToken
                if let accessToken = response["accessToken"] as? String {
                    // 保存token
                    UserDefaults.standard.set(accessToken, forKey: "accessToken")
                    isLoggedIn = true
                    loadingMessage = "登录成功"

                    // 🔥 登录成功后，立即获取每日挑战来验证认证
                    print("🔑 步骤 2: 登录成功，Token 已保存")
                    print("🚀 步骤 3: 立即获取每日挑战验证认证...")

                    Task {
                        do {
                            let challenge = try await EvalAPIClient.shared.fetchDailyChallenge(persona: .examPrep)
                            await MainActor.run {
                                print("✅ 认证验证成功！每日挑战: \(challenge.title)")
                                loadingMessage = "登录并验证成功"
                            }
                        } catch {
                            await MainActor.run {
                                print("⚠️ 认证验证失败，但登录成功: \(error.localizedDescription)")
                                // 不影响登录成功，但记录警告
                                loadingMessage = "登录成功（认证待验证）"
                            }
                        }
                    }
                } else {
                    showError(message: "后端响应中没有accessToken")
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                showError(message: "登录失败：\(error.localizedDescription)")
            }
        }
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }

    // MARK: - 辅助方法
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }
}