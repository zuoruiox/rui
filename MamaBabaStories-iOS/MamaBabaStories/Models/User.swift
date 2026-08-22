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
    var avatar: String?
    var phone: String?
    var email: String?
    var wechatOpenId: String?
    var deviceId: String?
    var role: String?
    var membershipTier: String?
    var membershipExpireAt: Date?
    var createdAt: Date?
    var updatedAt: Date?
    var children: [Child]?
    var lastLoginAt: Date?

    // 兼容计算属性
    var avatarURL: String? { avatar }
    var membershipTierEnum: MembershipTier {
        MembershipTier(rawValue: membershipTier ?? "free") ?? .free
    }
    var membershipExpiryDate: Date? { membershipExpireAt }
    var settings: UserSettings { .default }

    // 是否为会员
    var isPremium: Bool {
        membershipTierEnum != .free
    }

    // 会员是否有效
    var isMembershipActive: Bool {
        guard isPremium, let expiry = membershipExpireAt else { return false }
        return expiry > Date()
    }

    // 是否为游客（通过设备ID登录，无邮箱/手机号/微信绑定）
    var isGuest: Bool {
        deviceId != nil && email == nil && phone == nil && wechatOpenId == nil
    }

    enum CodingKeys: String, CodingKey {
        case id, nickname, avatar, phone, email, role
        case wechatOpenId, deviceId
        case membershipTier, membershipExpireAt, createdAt, updatedAt, children
        case lastLoginAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? "用户"
        avatar = try container.decodeIfPresent(String.self, forKey: .avatar)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        wechatOpenId = try container.decodeIfPresent(String.self, forKey: .wechatOpenId)
        deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
        role = try container.decodeIfPresent(String.self, forKey: .role)
        membershipTier = try container.decodeIfPresent(String.self, forKey: .membershipTier)
        membershipExpireAt = try container.decodeIfPresent(Date.self, forKey: .membershipExpireAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        children = try container.decodeIfPresent([Child].self, forKey: .children)
        lastLoginAt = try container.decodeIfPresent(Date.self, forKey: .lastLoginAt)
    }

    init(id: String, nickname: String, avatar: String? = nil, phone: String? = nil, email: String? = nil,
         wechatOpenId: String? = nil, deviceId: String? = nil,
         role: String? = nil, membershipTier: String? = "free", membershipExpireAt: Date? = nil,
         createdAt: Date? = nil, updatedAt: Date? = nil, children: [Child]? = nil, lastLoginAt: Date? = nil) {
        self.id = id
        self.nickname = nickname
        self.avatar = avatar
        self.phone = phone
        self.email = email
        self.wechatOpenId = wechatOpenId
        self.deviceId = deviceId
        self.role = role
        self.membershipTier = membershipTier
        self.membershipExpireAt = membershipExpireAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.children = children
        self.lastLoginAt = lastLoginAt
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

// MARK: - 会员等级
enum MembershipTier: String {
    case free = "free"
    case premium = "premium"
    case vip = "vip"
    case family = "family"

    var displayName: String {
        switch self {
        case .free: return "普通用户"
        case .premium: return "高级会员"
        case .vip: return "VIP会员"
        case .family: return "家庭会员"
        }
    }
}

// MARK: - Mock 数据
extension User {
    static let mock = User(
        id: "user_001",
        nickname: "温暖妈妈",
        avatar: nil,
        phone: "138****8888",
        email: nil,
        membershipTier: "premium",
        membershipExpireAt: Calendar.current.date(byAdding: .month, value: 6, to: Date()),
        createdAt: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
        updatedAt: Date(),
        children: [Child.mock]
    )

    static let mockFree = User(
        id: "user_002",
        nickname: "新手爸爸",
        avatar: nil,
        phone: "139****9999",
        email: nil,
        membershipTier: "free",
        membershipExpireAt: nil,
        createdAt: Date(),
        updatedAt: Date(),
        children: []
    )
}
