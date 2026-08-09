//
//  ProfileViewModel.swift
//  MamaBabaStories
//
//  个人中心 ViewModel
//

import Foundation
import Combine
import SwiftUI

@MainActor
class ProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var user: User?
    @Published var children: [Child] = []
    @Published var voiceModels: [VoiceModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    // 设置
    @Published var kidModeEnabled = false
    @Published var autoDownloadOnWiFi = true
    @Published var notificationsEnabled = true
    @Published var darkModeEnabled = false

    // 统计
    @Published var totalStoriesPlayed = 0
    @Published var totalListeningMinutes = 0
    @Published var favoriteStoriesCount = 0
    @Published var downloadedStoriesCount = 0

    // UI 状态
    @Published var showingAddChild = false
    @Published var showingMembershipPage = false
    @Published var showingSettings = false
    @Published var showingVoiceManagement = false
    @Published var editingChild: Child?
    @Published var newChildName = ""
    @Published var newChildGender: Gender = .boy
    @Published var newChildBirthDate = Date()
    @Published var newChildEmoji = "🦁"

    // MARK: - Init
    init() {
        loadPreferences()
        loadMockData()
    }

    // MARK: - 加载数据
    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await Task.sleep(nanoseconds: 500_000_000)
            // 实际项目中调用 API
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Mock 数据
    private func loadMockData() {
        user = .mock
        children = [.mock, .mockGirl]
        voiceModels = [.mockMom, .mockDad]
        totalStoriesPlayed = 42
        totalListeningMinutes = 380
        favoriteStoriesCount = 8
        downloadedStoriesCount = 5
    }

    // MARK: - 偏好设置
    private func loadPreferences() {
        let defaults = UserDefaults.standard
        kidModeEnabled = defaults.bool(forKey: UserDefaultsKeys.kidModeEnabled)
        autoDownloadOnWiFi = defaults.object(forKey: UserDefaultsKeys.autoDownloadOnWiFi) as? Bool ?? true
    }

    func savePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(kidModeEnabled, forKey: UserDefaultsKeys.kidModeEnabled)
        defaults.set(autoDownloadOnWiFi, forKey: UserDefaultsKeys.autoDownloadOnWiFi)
    }

    // MARK: - 孩子管理
    func addChild() {
        guard !newChildName.isEmpty else { return }

        let child = Child(
            id: "child_\(Date().timeIntervalSince1970)",
            name: newChildName,
            gender: newChildGender,
            birthDate: newChildBirthDate,
            avatarEmoji: newChildEmoji,
            favoriteThemes: [],
            createdAt: Date()
        )

        children.append(child)
        resetAddChildForm()
        showingAddChild = false
    }

    func updateChild(_ child: Child) {
        if let index = children.firstIndex(where: { $0.id == child.id }) {
            children[index] = child
        }
        editingChild = nil
    }

    func deleteChild(_ child: Child) {
        children.removeAll { $0.id == child.id }
    }

    private func resetAddChildForm() {
        newChildName = ""
        newChildGender = .boy
        newChildBirthDate = Date()
        newChildEmoji = "🦁"
    }

    // MARK: - 会员相关
    var membershipText: String {
        guard let user = user else { return "未登录" }
        if user.isMembershipActive {
            if let expiry = user.membershipExpiryDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy年MM月dd日"
                return "\(user.membershipTier.rawValue) · 到期\(formatter.string(from: expiry))"
            }
            return user.membershipTier.rawValue
        }
        return "开通会员，解锁更多功能"
    }

    // MARK: - 设置项
    var settingsSections: [SettingsSection] {
        [
            SettingsSection(title: "播放设置", items: [
                SettingsItem(icon: "speedometer", title: "播放速度", value: "1.0x", type: .navigation),
                SettingsItem(icon: "timer", title: "睡眠定时", value: "未开启", type: .navigation),
                SettingsItem(icon: "arrow.down.circle", title: "WiFi自动下载", value: nil, type: .toggle(\.autoDownloadOnWiFi)),
            ]),
            SettingsSection(title: "儿童模式", items: [
                SettingsItem(icon: "hand.raised.fill", title: "儿童模式", value: nil, type: .toggle(\.kidModeEnabled)),
            ]),
            SettingsSection(title: "通知", items: [
                SettingsItem(icon: "bell.fill", title: "推送通知", value: nil, type: .toggle(\.notificationsEnabled)),
            ]),
            SettingsSection(title: "其他", items: [
                SettingsItem(icon: "star.fill", title: "给我们评分", value: nil, type: .action),
                SettingsItem(icon: "envelope.fill", title: "意见反馈", value: nil, type: .action),
                SettingsItem(icon: "doc.text.fill", title: "用户协议", value: nil, type: .navigation),
                SettingsItem(icon: "lock.fill", title: "隐私政策", value: nil, type: .navigation),
                SettingsItem(icon: "info.circle.fill", title: "关于我们", value: AppInfo.appVersion, type: .navigation),
            ])
        ]
    }

    // MARK: - 退出登录
    func logout() {
        user = nil
        KeychainHelper.shared.delete(for: KeychainKeys.authToken)
        KeychainHelper.shared.delete(for: KeychainKeys.refreshToken)
    }
}

// MARK: - 设置模型
struct SettingsSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [SettingsItem]
}

struct SettingsItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let value: String?
    let type: SettingsItemType

    enum SettingsItemType {
        case navigation
        case toggle(ReferenceWritableKeyPath<ProfileViewModel, Bool>)
        case action
    }
}
