//
//  LoginView.swift
//  MamaBabaStories
//
//  登录页面 - 支持手机号验证码登录/注册、微信登录、邮箱登录
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showPhoneLogin = false
    @State private var showEmailLogin = false

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
                    // 手机号一键登录/注册
                    Button(action: { showPhoneLogin = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "smartphone.fill")
                                .font(.system(size: 18))
                            Text("手机号一键登录/注册")
                                .font(AppFonts.button())
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: Layout.buttonHeight)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [AppColors.warmYellow, AppColors.softOrange]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
                    }

                    // 微信登录
                    Button(action: {
                        Task {
                            await authService.loginWithWechat(code: "wx_\(UUID().uuidString.prefix(8))")
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

                    // 邮箱登录
                    Button(action: { showEmailLogin = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 18))
                            Text("邮箱登录")
                                .font(AppFonts.button())
                        }
                        .foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: Layout.buttonHeight)
                        .background(AppColors.surfaceVariant)
                        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
                    }
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
        .sheet(isPresented: $showPhoneLogin) {
            PhoneLoginView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showEmailLogin) {
            EmailLoginView()
                .environmentObject(authService)
        }
        .alert("提示", isPresented: $authService.showError) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(authService.errorMessage ?? "未知错误")
        }
    }
}

// MARK: - 手机号登录/注册
struct PhoneLoginView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var phone = ""
    @State private var code = ""
    @State private var countdown = 0
    @State private var timer: Timer?
    @State private var showNicknameInput = false
    @State private var nickname = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    // 手机号输入
                    VStack(alignment: .leading, spacing: 6) {
                        Text("手机号")
                            .font(AppFonts.caption(size: 13, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)

                        HStack(spacing: 12) {
                            Text("+86")
                                .font(AppFonts.body())
                                .foregroundColor(AppColors.textPrimary)
                                .padding(.leading, 4)

                            Rectangle()
                                .fill(AppColors.textTertiary.opacity(0.3))
                                .frame(width: 1, height: 20)

                            TextField("请输入手机号", text: $phone)
                                .font(AppFonts.body())
                                .keyboardType(.numberPad)
                                .onChange(of: phone) { newValue in
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered != newValue { phone = filtered }
                                    if phone.count > 11 { phone = String(phone.prefix(11)) }
                                }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.surfaceVariant)
                        )
                    }

                    // 验证码输入
                    VStack(alignment: .leading, spacing: 6) {
                        Text("验证码")
                            .font(AppFonts.caption(size: 13, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)

                        HStack(spacing: 12) {
                            TextField("请输入验证码", text: $code)
                                .font(AppFonts.body())
                                .keyboardType(.numberPad)
                                .onChange(of: code) { newValue in
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered != newValue { code = filtered }
                                    if code.count > 6 { code = String(code.prefix(6)) }
                                }

                            Button(action: sendCode) {
                                Text(countdown > 0 ? "\(countdown)s后重发" : "获取验证码")
                                    .font(AppFonts.caption(size: 14, weight: .medium))
                                    .foregroundColor(countdown > 0 ? AppColors.textTertiary : .white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(countdown > 0 ? AppColors.surfaceVariant : AppColors.softOrange)
                                    )
                            }
                            .disabled(countdown > 0 || phone.count != 11 || authService.isLoading)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.surfaceVariant)
                        )
                    }

                    // 登录/注册按钮
                    PrimaryButton("登录/注册", icon: "arrow.right", isDisabled: phone.count != 11 || code.count != 6, isLoading: authService.isLoading) {
                        performLogin()
                    }
                    .padding(.top, 8)

                    Spacer()
                }
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.top, 30)
            }
            .navigationTitle("手机号登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .onDisappear { timer?.invalidate() }
        .alert("设置昵称", isPresented: $showNicknameInput) {
            TextField("请输入昵称", text: $nickname)
            Button("确定") {
                Task {
                    let success = await authService.loginWithPhone(phone: phone, code: code, nickname: nickname)
                    if success { dismiss() }
                }
            }
            Button("跳过", role: .cancel) {
                Task {
                    let success = await authService.loginWithPhone(phone: phone, code: code)
                    if success { dismiss() }
                }
            }
        } message: {
            Text("欢迎使用！请设置您的昵称")
        }
        .alert("登录失败", isPresented: Binding(
            get: { authService.showError && !showNicknameInput },
            set: { authService.showError = $0 }
        )) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(authService.errorMessage ?? "未知错误")
        }
    }

    private func sendCode() {
        guard phone.count == 11 else { return }
        Task {
            if let devCode = await authService.sendVerificationCode(phone: phone) {
                // DEBUG 模式自动填充验证码方便测试
                #if DEBUG
                code = devCode
                #endif
                startCountdown()
            }
        }
    }

    private func performLogin() {
        Task {
            let success = await authService.loginWithPhone(phone: phone, code: code)
            if success {
                dismiss()
            }
        }
    }

    private func startCountdown() {
        countdown = 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if countdown > 0 {
                    countdown -= 1
                } else {
                    timer?.invalidate()
                    timer = nil
                }
            }
        }
    }
}

// MARK: - 邮箱登录
struct EmailLoginView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isSecured = true
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                VStack(spacing: 20) {
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

                    // 登录按钮
                    PrimaryButton("登录", icon: "arrow.right", isDisabled: email.isEmpty || password.isEmpty, isLoading: authService.isLoading) {
                        Task {
                            let success = await authService.loginWithEmail(email: email, password: password)
                            if success { dismiss() }
                        }
                    }
                    .padding(.top, 8)

                    // 注册入口
                    HStack {
                        Text("还没有账号？")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.textSecondary)
                        Button("立即注册") {
                            showRegister = true
                        }
                        .font(AppFonts.caption(weight: .medium))
                        .foregroundColor(AppColors.softOrange)
                    }

                    Spacer()
                }
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.top, 30)
            }
            .navigationTitle("邮箱登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showRegister) {
            EmailRegisterView()
                .environmentObject(authService)
        }
        .alert("登录失败", isPresented: Binding(
            get: { authService.showError && !showRegister },
            set: { authService.showError = $0 }
        )) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(authService.errorMessage ?? "未知错误")
        }
    }
}

// MARK: - 邮箱注册
struct EmailRegisterView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var nickname = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSecured = true

    private var canRegister: Bool {
        !nickname.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.isEmpty && email.contains("@") &&
        password.count >= 6 &&
        password == confirmPassword
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                VStack(spacing: 16) {
                    // 昵称
                    VStack(alignment: .leading, spacing: 6) {
                        Text("昵称")
                            .font(AppFonts.caption(size: 13, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                        TextField("请输入昵称", text: $nickname)
                            .font(AppFonts.body())
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppColors.surfaceVariant)
                            )
                    }

                    // 邮箱
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

                    // 密码
                    VStack(alignment: .leading, spacing: 6) {
                        Text("密码（至少6位）")
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

                    // 确认密码
                    VStack(alignment: .leading, spacing: 6) {
                        Text("确认密码")
                            .font(AppFonts.caption(size: 13, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                        SecureField("请再次输入密码", text: $confirmPassword)
                            .font(AppFonts.body())
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppColors.surfaceVariant)
                            )
                    }

                    // 注册按钮
                    PrimaryButton("注册", icon: "checkmark", isDisabled: !canRegister, isLoading: authService.isLoading) {
                        Task {
                            let success = await authService.registerWithEmail(
                                email: email,
                                password: password,
                                nickname: nickname.trimmingCharacters(in: .whitespaces)
                            )
                            if success {
                                dismiss()
                            }
                        }
                    }
                    .padding(.top, 8)

                    Spacer()
                }
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.top, 20)
            }
            .navigationTitle("注册账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .alert("注册失败", isPresented: $authService.showError) {
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
