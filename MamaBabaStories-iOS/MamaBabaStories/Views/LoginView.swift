//
//  LoginView.swift
//  MamaBabaStories
//
//  登录页面 - 支持微信登录/注册、游客模式
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService

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

                // 登录按钮区域
                VStack(spacing: 14) {
                    // 微信登录/注册
                    Button(action: {
                        Task {
                            // TODO: 集成微信开放平台 SDK
                            // 1. 在 Info.plist 配置微信 URL Scheme（wx + appId）
                            // 2. 调用 WXApi.send(AuthReq) 发起授权
                            // 3. 在 AppDelegate/SceneDelegate 的 openURL 回调中获取 code
                            // 4. 将 code 传给后端换取 openId 和 token
                            // 当前使用基于设备ID的稳定 mock openId 方便开发测试
                            let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
                            let mockOpenId = "wx_mock_\(deviceId.prefix(12))"
                            await authService.loginWithWechat(code: mockOpenId)
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "message.fill")
                                .font(.system(size: 18))
                            Text("微信登录/注册")
                                .font(AppFonts.button())
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: Layout.buttonHeight)
                        .background(Color(red: 0.07, green: 0.73, blue: 0.35))
                        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
                    }
                    .disabled(authService.isLoading)
                }
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.top, 8)

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
                .padding(.top, 20)
                .disabled(authService.isLoading)

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
