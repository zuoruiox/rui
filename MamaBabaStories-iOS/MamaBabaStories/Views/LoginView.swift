//
//  LoginView.swift
//  MamaBabaStories
//
//  登录页面 - 微信登录/注册
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isLoggingIn = false

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

                // 微信登录/注册按钮
                Button(action: {
                    isLoggingIn = true
                    WeChatManager.shared.sendAuthRequest()
                }) {
                    HStack(spacing: 10) {
                        if isLoggingIn || authService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "message.fill")
                                .font(.system(size: 18))
                        }
                        Text("微信登录/注册")
                            .font(AppFonts.button())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: Layout.buttonHeight)
                    .background(Color(red: 0.07, green: 0.73, blue: 0.35))
                    .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
                }
                .disabled(isLoggingIn || authService.isLoading)
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.top, 8)

                Spacer()

                // 底部提示
                HStack(spacing: 4) {
                    Text("登录即表示同意")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textTertiary)
                    Button("用户协议") { }
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.gentleBlue)
                    Text("和")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textTertiary)
                    Button("隐私政策") { }
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.gentleBlue)
                }
                .padding(.bottom, 20)
            }
        }
        .alert("提示", isPresented: $authService.showError) {
            Button("好的", role: .cancel) {
                isLoggingIn = false
            }
        } message: {
            Text(authService.errorMessage ?? "未知错误")
        }
        .onReceive(NotificationCenter.default.publisher(for: .wechatLoginSuccess)) { _ in
            isLoggingIn = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .wechatLoginFailure)) { _ in
            isLoggingIn = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .wechatLoginCancel)) { _ in
            isLoggingIn = false
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
