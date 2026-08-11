//
//  AppConstants.swift
//  MamaBabaStories
//
//  应用全局常量定义
//

import SwiftUI

// MARK: - App 信息
enum AppInfo {
    static let appName = "爸爸妈妈讲故事"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    static let bundleId = "com.mamababa.stories"
}

// MARK: - API 配置
enum APIConfig {
    #if DEBUG
    // 模拟器使用 Mac 的 IP 地址访问本地服务器
    static let baseURL = "http://10.21.10.202:9999/api"
    static let wsBaseURL = "ws://10.21.10.202:9999/api"
    #else
    static let baseURL = "https://api.mamababa-stories.com/api"
    static let wsBaseURL = "wss://api.mamababa-stories.com/api"
    #endif

    static let timeout: TimeInterval = 30
    static let uploadTimeout: TimeInterval = 120
}

// MARK: - Keychain Keys
enum KeychainKeys {
    static let authToken = "com.mamababa.authToken"
    static let refreshToken = "com.mamababa.refreshToken"
    static let userId = "com.mamababa.userId"
}

// MARK: - UserDefaults Keys
enum UserDefaultsKeys {
    static let hasOnboarded = "hasOnboarded"
    static let preferredPlaybackSpeed = "preferredPlaybackSpeed"
    static let sleepTimerMinutes = "sleepTimerMinutes"
    static let autoDownloadOnWiFi = "autoDownloadOnWiFi"
    static let kidModeEnabled = "kidModeEnabled"
    static let lastPlayedStoryId = "lastPlayedStoryId"
    static let lastPlayPosition = "lastPlayPosition"
}

// MARK: - 音频配置
enum AudioConfig {
    static let sampleRate: Double = 24000
    static let channels: UInt32 = 1
    static let bitsPerChannel: UInt32 = 16
    static let recordingFormat = "wav"

    // VAD 参数
    static let vadEnergyThreshold: Float = 0.02
    static let vadSilenceDuration: TimeInterval = 1.5

    // 录音质量检测
    static let minSNR: Float = 15.0  // 最小信噪比 (dB)
    static let clippingThreshold: Float = 0.95  // 削波阈值

    // 录音时长要求
    static let minRecordingDuration: TimeInterval = 30  // 最少30秒
    static let maxRecordingDuration: TimeInterval = 300  // 最多5分钟
    static let recommendedDuration: TimeInterval = 60  // 推荐1分钟

    // 播放速度选项
    static let playbackSpeeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5]
    static let defaultPlaybackSpeed: Float = 1.0

    // 睡眠定时器选项（分钟）
    static let sleepTimerOptions: [Int] = [15, 30, 45, 60, 90]
}

// MARK: - 语音克隆配置
enum VoiceCloneConfig {
    static let minRecordings = 3
    static let maxRecordings = 10
    static let pollingInterval: TimeInterval = 3.0
    static let maxPollingAttempts = 60  // 最多轮询3分钟
}

// MARK: - 颜色主题
enum AppColors {
    // 主色调 - 温暖橙色系
    static let primary = Color("PrimaryColor", bundle: nil)
    static let primaryLight = Color("PrimaryLight", bundle: nil)
    static let primaryDark = Color("PrimaryDark", bundle: nil)

    // 辅助色
    static let secondary = Color("SecondaryColor", bundle: nil)
    static let accent = Color("AccentColor", bundle: nil)

    // 温暖黄色
    static let warmYellow = Color(red: 1.0, green: 0.87, blue: 0.42)
    static let softOrange = Color(red: 1.0, green: 0.65, blue: 0.35)

    // 柔和蓝色
    static let gentleBlue = Color(red: 0.45, green: 0.65, blue: 0.85)
    static let softBlue = Color(red: 0.6, green: 0.78, blue: 0.95)

    // 柔和粉色
    static let softPink = Color(red: 1.0, green: 0.75, blue: 0.80)

    // 柔和绿色
    static let softGreen = Color(red: 0.6, green: 0.85, blue: 0.65)

    // 背景色
    static let background = Color(red: 0.99, green: 0.97, blue: 0.94)  // 暖白
    static let surface = Color.white
    static let surfaceVariant = Color(red: 0.96, green: 0.94, blue: 0.91)

    // 文字颜色
    static let textPrimary = Color(red: 0.2, green: 0.15, blue: 0.1)
    static let textSecondary = Color(red: 0.5, green: 0.45, blue: 0.4)
    static let textTertiary = Color(red: 0.7, green: 0.65, blue: 0.6)

    // 状态色
    static let success = Color(red: 0.3, green: 0.75, blue: 0.4)
    static let warning = Color(red: 1.0, green: 0.75, blue: 0.2)
    static let error = Color(red: 0.95, green: 0.35, blue: 0.35)
    static let info = Color(red: 0.4, green: 0.6, blue: 0.9)
}

// MARK: - 字体
enum AppFonts {
    static func title(size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func headline(size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func body(size: CGFloat = 16, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func caption(size: CGFloat = 13, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func button(size: CGFloat = 17) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}

// MARK: - 布局常量
enum Layout {
    static let cornerRadius: CGFloat = 16
    static let largeCornerRadius: CGFloat = 24
    static let smallCornerRadius: CGFloat = 10
    static let buttonHeight: CGFloat = 52
    static let largeButtonHeight: CGFloat = 60
    static let cardPadding: CGFloat = 16
    static let horizontalPadding: CGFloat = 20
    static let verticalPadding: CGFloat = 16
    static let shadowRadius: CGFloat = 8
    static let shadowY: CGFloat = 4
}

// MARK: - 故事主题
enum StoryTheme: String, CaseIterable, Codable, Identifiable {
    case adventure = "冒险"
    case friendship = "友谊"
    case family = "家庭"
    case animals = "动物"
    case magic = "魔法"
    case space = "太空"
    case nature = "自然"
    case bedtime = "睡前"
    case courage = "勇气"
    case kindness = "善良"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .adventure: return "map.fill"
        case .friendship: return "heart.fill"
        case .family: return "house.fill"
        case .animals: return "pawprint.fill"
        case .magic: return "sparkles"
        case .space: return "moon.stars.fill"
        case .nature: return "leaf.fill"
        case .bedtime: return "moon.fill"
        case .courage: return "shield.fill"
        case .kindness: return "hand.raised.fill"
        }
    }

    var color: Color {
        switch self {
        case .adventure: return AppColors.softOrange
        case .friendship: return AppColors.softPink
        case .family: return AppColors.warmYellow
        case .animals: return AppColors.softGreen
        case .magic: return AppColors.gentleBlue
        case .space: return Color(red: 0.5, green: 0.4, blue: 0.8)
        case .nature: return AppColors.softGreen
        case .bedtime: return AppColors.gentleBlue
        case .courage: return AppColors.softOrange
        case .kindness: return AppColors.warmYellow
        }
    }
}

// MARK: - 故事风格
enum StoryStyle: String, CaseIterable, Codable, Identifiable {
    case warm = "温馨"
    case humorous = "幽默"
    case exciting = "紧张刺激"
    case educational = "寓教于乐"
    case poetic = "诗意优美"
    case fairy = "童话"

    var id: String { rawValue }
}

// MARK: - 年龄段
enum AgeGroup: String, CaseIterable, Codable, Identifiable {
    case toddler = "2-3岁"
    case preschool = "4-5岁"
    case earlyElementary = "6-8岁"
    case lateElementary = "9-12岁"

    var id: String { rawValue }

    var range: ClosedRange<Int> {
        switch self {
        case .toddler: return 2...3
        case .preschool: return 4...5
        case .earlyElementary: return 6...8
        case .lateElementary: return 9...12
        }
    }
}

// MARK: - 会员等级
enum MembershipTier: String, Codable {
    case free = "免费版"
    case premium = "会员版"
    case family = "家庭版"

    var maxVoiceModels: Int {
        switch self {
        case .free: return 1
        case .premium: return 3
        case .family: return 6
        }
    }

    var maxStoriesPerDay: Int {
        switch self {
        case .free: return 3
        case .premium: return 20
        case .family: return 50
        }
    }

    var canDownload: Bool {
        switch self {
        case .free: return false
        case .premium, .family: return true
        }
    }
}
