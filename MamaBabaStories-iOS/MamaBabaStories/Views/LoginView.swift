//
//  LoginView.swift
//  MamaBabaStories
//
//  登录页面
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var isSecured = true

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo 和标题
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [AppColors.warmYellow, AppColors.softOrange]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)

                        Image(systemName: "book.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                    }

                    Text("爸爸妈妈讲故事")
                        .font(AppFonts.title(size: 28))
                        .foregroundColor(AppColors.textPrimary)

                    Text("用你的声音，给宝贝讲温暖的故事")
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.bottom, 50)

                // 登录表单
                VStack(spacing: 16) {
                    // 邮箱输入
                    VStack(alignment: .leading, spacing: 6) {
                        Text("邮箱")
                            .font(AppFonts.caption(size: 13, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)

                        TextField("请输入邮箱", text: $email)
                            .font(AppFonts.body())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppColors.surfaceVariant)
                            )
                    }

                    // 密码输入
                    VStack(alignment: .leading, spacing: 6) {
                        Text("密码")
                            .font(AppFonts.caption(size: 13, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)

                        HStack {
                            if isSecured {
                                SecureField("请输入密码", text: $password)
                                    .font(AppFonts.body())
                            } else {
                                TextField("请输入密码", text: $password)
                                    .font(AppFonts.body())
                            }

                            Button(action: { isSecured.toggle() }) {
                                Image(systemName: isSecured ? "eye.slash" : "eye")
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.surfaceVariant)
                        )
                    }
                }
                .padding(.horizontal, Layout.horizontalPadding)

                // 登录按钮
                PrimaryButton("登录", icon: "arrow.right", isDisabled: email.isEmpty || password.isEmpty, isLoading: authService.isLoading) {
                    Task {
                        _ = await authService.loginWithEmail(email: email, password: password)
                    }
                }
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.top, 24)

                // 游客模式
                Button(action: {
                    Task {
                        await authService.deviceLogin()
                    }
                }) {
                    HStack(spacing: 6) {
                        if authService.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "person.crop.circle")
                        }
                        Text("游客模式，直接体验")
                    }
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textSecondary)
                }
                .padding(.top, 16)
                .disabled(authService.isLoading)

                Spacer()

                // 底部提示
                Text("登录即表示同意用户协议和隐私政策")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.bottom, 20)
            }
        }
        .alert("登录失败", isPresented: $authService.showError) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(authService.errorMessage ?? "未知错误")
        }
    }
}

// MARK: - 预览
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthService())
    }
}