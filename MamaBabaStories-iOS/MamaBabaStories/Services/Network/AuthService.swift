//
//  AuthService.swift
//  MamaBabaStories
//
//  认证服务
//

import Foundation
import UIKit
import Combine

// MARK: - 登录响应
struct LoginResponse: Codable {
    let token: String
    let user: User
}

// MARK: - AuthService
@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    private let apiClient: APIClientProtocol
    private var hasValidatedToken = false

    init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    // MARK: - 验证现有 token（App 启动时调用）
    func validateExistingToken() async {
        guard let token = KeychainHelper.shared.getString(for: KeychainKeys.authToken) else {
            isAuthenticated = false
            return
        }

        APIClient.shared.setAuthToken(token)

        // 用 /auth/me 验证 token 是否有效
        do {
            let user: User = try await apiClient.request(.getMe)
            currentUser = user
            isAuthenticated = true
            Logger.info("Token 验证成功: \(user.nickname)", category: .network)
        } catch {
            // token 无效，清除
            Logger.warning("Token 验证失败，清除: \(error)", category: .network)
            APIClient.shared.setAuthToken(nil)
            KeychainHelper.shared.delete(for: KeychainKeys.authToken)
            isAuthenticated = false
            currentUser = nil
        }
        hasValidatedToken = true
    }

    // MARK: - 设备自动登录（游客模式）
    func deviceLogin() async {
        guard !isAuthenticated else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let deviceId = getOrCreateDeviceId()
            let response: LoginResponse = try await apiClient.request(.deviceLogin(deviceId: deviceId))
            APIClient.shared.setAuthToken(response.token)
            currentUser = response.user
            isAuthenticated = true
            Logger.info("设备登录成功: \(response.user.nickname)", category: .network)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            Logger.error("设备登录失败: \(error)", category: .network)
        }
    }

    // MARK: - 邮箱登录
    func loginWithEmail(email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: LoginResponse = try await apiClient.request(
                .loginWithEmail(email: email, password: password)
            )
            APIClient.shared.setAuthToken(response.token)
            currentUser = response.user
            isAuthenticated = true
            Logger.info("邮箱登录成功: \(response.user.nickname)", category: .network)
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            Logger.error("邮箱登录失败: \(error)", category: .network)
            return false
        }
    }

    // MARK: - 邮箱注册
    func registerWithEmail(email: String, password: String, nickname: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: LoginResponse = try await apiClient.request(
                .registerWithEmail(email: email, password: password, nickname: nickname)
            )
            APIClient.shared.setAuthToken(response.token)
            currentUser = response.user
            isAuthenticated = true
            Logger.info("邮箱注册成功: \(response.user.nickname)", category: .network)
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            Logger.error("邮箱注册失败: \(error)", category: .network)
            return false
        }
    }

    // MARK: - 发送验证码
    func sendVerificationCode(phone: String) async -> String? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            struct CodeResponse: Codable { let devCode: String? }
            let response: CodeResponse = try await apiClient.request(.sendCode(phone: phone))
            Logger.info("验证码发送成功", category: .network)
            return response.devCode
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            Logger.error("验证码发送失败: \(error)", category: .network)
            return nil
        }
    }

    // MARK: - 手机号登录/注册
    func loginWithPhone(phone: String, code: String, nickname: String? = nil) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: LoginResponse = try await apiClient.request(
                .phoneLogin(phone: phone, code: code, nickname: nickname)
            )
            APIClient.shared.setAuthToken(response.token)
            currentUser = response.user
            isAuthenticated = true
            Logger.info("手机号登录成功: \(response.user.nickname)", category: .network)
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            Logger.error("手机号登录失败: \(error)", category: .network)
            return false
        }
    }

    // MARK: - 微信登录
    func loginWithWechat(code: String, nickname: String? = nil, avatar: String? = nil) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: LoginResponse = try await apiClient.request(
                .wechatLogin(code: code, nickname: nickname, avatar: avatar)
            )
            APIClient.shared.setAuthToken(response.token)
            currentUser = response.user
            isAuthenticated = true
            Logger.info("微信登录成功: \(response.user.nickname)", category: .network)
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            Logger.error("微信登录失败: \(error)", category: .network)
            return false
        }
    }

    // MARK: - 退出登录
    func logout() {
        APIClient.shared.setAuthToken(nil)
        KeychainHelper.shared.delete(for: KeychainKeys.authToken)
        currentUser = nil
        isAuthenticated = false
    }

    // MARK: - 获取或创建设备 ID
    private func getOrCreateDeviceId() -> String {
        let key = "com.mamababa.deviceId"
        if let existingId = UserDefaults.standard.string(forKey: key) {
            return existingId
        }
        let newId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
}