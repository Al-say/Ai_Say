import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var viewModel: LoginViewModel

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Logo和标题
                VStack(spacing: 20) {
                    Image(systemName: "waveform.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)

                    Text("AI Say")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text("智能英语学习助手")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 登录按钮
                VStack(spacing: 20) {
                    if viewModel.isRegisterMode {
                        // 注册模式
                        VStack(spacing: 15) {
                            TextField("用户名", text: $viewModel.registerUsername)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                            
                            TextField("邮箱", text: $viewModel.registerEmail)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                            
                            SecureField("密码", text: $viewModel.password)
                                .textFieldStyle(.roundedBorder)
                            
                            SecureField("确认密码", text: $viewModel.confirmPassword)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("注册") {
                                Task { await viewModel.register() }
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            
                            Button("已有账号？去登录") {
                                viewModel.isRegisterMode = false
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 40)
                    } else {
                        // 登录模式
                        VStack(spacing: 15) {
                            TextField("用户名或邮箱", text: $viewModel.usernameOrEmail)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                            
                            SecureField("密码", text: $viewModel.password)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("登录") {
                                Task { await viewModel.loginWithCredentials() }
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            
                            Button("没有账号？去注册") {
                                viewModel.isRegisterMode = true
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 40)
                        

                    }

                    Text("继续即表示您同意我们的服务条款")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding()

            // 加载状态覆盖层
            if viewModel.isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text(viewModel.loadingMessage)
                                .foregroundColor(.white)
                        }
                    )
            }
        }
        .alert("登录失败", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}

#Preview {
    LoginView()
}