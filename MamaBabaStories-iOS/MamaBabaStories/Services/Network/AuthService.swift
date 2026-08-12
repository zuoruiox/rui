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

    init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
        // 检查是否已有 token
        if let token = KeychainHelper.shared.getString(for: KeychainKeys.authToken) {
            APIClient.shared.setAuthToken(token)
            isAuthenticated = true
        }
    }

    // MARK: - 设备自动登录（首次启动）
    func deviceLogin() async {
        guard !isAuthenticated else { return }

        isLoading = true
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