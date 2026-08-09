//
//  User.swift
//  MamaBabaStories
//
//  用户数据模型
//

import Foundation
import SwiftUI

// MARK: - 用户模型
struct User: Codable, Identifiable {
    let id: String
    var nickname: String
    var avatarURL: String?
    var phone: String?
    var email: String?
    var membershipTier: MembershipTier
    var membershipExpiryDate: Date?
    var createdAt: Date
    var updatedAt: Date
    var children: [Child]
    var settings: UserSettings

    // 是否为会员
    var isPremium: Bool {
        membershipTier != .free
    }

    // 会员是否有效
    var isMembershipActive: Bool {
        guard isPremium, let expiry = membershipExpiryDate else { return false }
        return expiry > Date()
    }
}

// MARK: - 用户设置
struct UserSettings: Codable {
    var kidModeEnabled: Bool
    var autoDownloadOnWiFi: Bool
    var preferredPlaybackSpeed: Float
    var notificationsEnabled: Bool
    var sleepTimerDefaultMinutes: Int?
    var darkModeEnabled: Bool?

    static let `default` = UserSettings(
        kidModeEnabled: false,
        autoDownloadOnWiFi: true,
        preferredPlaybackSpeed: 1.0,
        notificationsEnabled: true,
        sleepTimerDefaultMinutes: nil,
        darkModeEnabled: nil
    )
}

// MARK: - 登录响应
struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: User
}

// MARK: - Mock 数据
extension User {
    static let mock = User(
        id: "user_001",
        nickname: "温暖妈妈",
        avatarURL: nil,
        phone: "138****8888",
        email: nil,
        membershipTier: .premium,
        membershipExpiryDate: Calendar.current.date(byAdding: .month, value: 6, to: Date()),
        createdAt: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
        updatedAt: Date(),
        children: [Child.mock],
        settings: .default
    )

    static let mockFree = User(
        id: "user_002",
        nickname: "新手爸爸",
        avatarURL: nil,
        phone: "139****9999",
        email: nil,
        membershipTier: .free,
        membershipExpiryDate: nil,
        createdAt: Date(),
        updatedAt: Date(),
        children: [],
        settings: .default
    )
}
