//
//  Extensions.swift
//  MamaBabaStories
//
//  Swift 扩展集合
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Date 扩展
extension Date {
    /// 格式化日期为中文显示
    func formattedChinese(style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    /// 相对时间描述（如"3分钟前"）
    var relativeTimeString: String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day, .weekOfYear, .month, .year], from: self, to: now)

        if let year = components.year, year >= 1 {
            return "\(year)年前"
        }
        if let month = components.month, month >= 1 {
            return "\(month)个月前"
        }
        if let week = components.weekOfYear, week >= 1 {
            return "\(week)周前"
        }
        if let day = components.day, day >= 1 {
            if day == 1 { return "昨天" }
            return "\(day)天前"
        }
        if let hour = components.hour, hour >= 1 {
            return "\(hour)小时前"
        }
        if let minute = components.minute, minute >= 1 {
            return "\(minute)分钟前"
        }
        return "刚刚"
    }

    /// 是否是今天
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// 是否是昨天
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
}

// MARK: - String 扩展
extension String {
    /// 截取指定长度
    func prefix(_ maxLength: Int) -> String {
        guard count > maxLength else { return self }
        return String(self[startIndex..<index(startIndex, offsetBy: maxLength)])
    }

    /// 去除空白和换行
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 是否为有效的手机号
    var isValidPhoneNumber: Bool {
        let pattern = "^1[3-9]\\d{9}$"
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: self)
    }

    /// 计算文本高度
    func height(withConstrainedWidth width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(
            with: constraintRect,
            options: .usesLineFragmentOrigin,
            attributes: [.font: font],
            context: nil
        )
        return ceil(boundingBox.height)
    }
}

// MARK: - Color 扩展
extension Color {
    /// 从十六进制字符串创建颜色
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// 转为 UIColor
    var uiColor: UIColor {
        UIColor(self)
    }
}

// MARK: - View 扩展
extension View {
    /// 条件修饰符
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// 隐藏键盘
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// 点击收起键盘
    func dismissKeyboardOnTap() -> some View {
        onTapGesture {
            hideKeyboard()
        }
    }

    /// 圆角边框
    func cornerBorder(radius: CGFloat = 12, color: Color = .gray.opacity(0.2), lineWidth: CGFloat = 1) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: radius)
                .stroke(color, lineWidth: lineWidth)
        )
        .cornerRadius(radius)
    }

    /// 标准卡片阴影
    func cardShadow() -> some View {
        shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    /// 读取视图尺寸
    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: geometry.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
}

// MARK: - SizePreferenceKey
private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}

// MARK: - TimeInterval 扩展
extension TimeInterval {
    /// 格式化为 分:秒
    var formattedAsPlaybackTime: String {
        guard self.isFinite, self >= 0 else { return "00:00" }
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// 格式化为中文时长描述
    var formattedDurationChinese: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else if minutes > 0 {
            return "\(minutes)分钟"
        } else {
            return "\(totalSeconds)秒"
        }
    }
}

// MARK: - Double 扩展
extension Double {
    /// 四舍五入到指定小数位
    func rounded(to places: Int) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (self * multiplier).rounded() / multiplier
    }
}

// MARK: - UserDefaults 扩展
extension UserDefaults {
    /// 安全获取 Codable 对象
    func codableObject<T: Codable>(forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// 安全存储 Codable 对象
    func setCodableObject<T: Codable>(_ object: T, forKey key: String) {
        let data = try? JSONEncoder().encode(object)
        set(data, forKey: key)
    }
}

// MARK: - Binding 扩展
extension Binding where Value == Bool {
    /// 取反绑定
    var not: Binding<Bool> {
        Binding<Bool>(
            get: { !wrappedValue },
            set: { wrappedValue = !$0 }
        )
    }
}

// MARK: - UIApplication 扩展
extension UIApplication {
    /// 获取当前顶部 ViewController
    var topViewController: UIViewController? {
        guard let windowScene = connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return nil
        }
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }
        return topController
    }

    /// 应用版本号
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// 构建号
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - FileManager 扩展
extension FileManager {
    /// 文档目录 URL
    static var documentsDirectory: URL {
        `default`.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// 缓存目录 URL
    static var cachesDirectory: URL {
        `default`.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

    /// 临时目录 URL
    static var temporaryDirectory: URL {
        `default`.temporaryDirectory
    }

    /// 获取目录大小（字节）
    func directorySize(at url: URL) -> Int64 {
        guard let enumerator = enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var size: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize else { continue }
            size += Int64(fileSize)
        }
        return size
    }

    /// 格式化文件大小
    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Data 扩展
extension Data {
    /// 格式化为合适的音频文件大小字符串
    var audioFileSizeString: String {
        FileManager.formatFileSize(Int64(count))
    }
}
