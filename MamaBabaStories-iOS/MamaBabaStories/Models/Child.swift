//
//  Child.swift
//  MamaBabaStories
//
//  孩子档案数据模型
//

import Foundation

// MARK: - 孩子档案
struct Child: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var gender: Gender
    var birthDate: Date
    var avatarEmoji: String
    var favoriteThemes: [String]
    var createdAt: Date

    // 计算年龄
    var age: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: birthDate, to: Date())
        return components.year ?? 0
    }

    // 年龄段
    var ageGroup: AgeGroup {
        switch age {
        case 2...3: return .toddler
        case 4...5: return .preschool
        case 6...8: return .earlyElementary
        case 9...12: return .lateElementary
        default: return .preschool
        }
    }
}

// MARK: - 性别
enum Gender: String, Codable, CaseIterable, Identifiable {
    case boy = "男孩"
    case girl = "女孩"
    case other = "保密"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .boy: return "👦"
        case .girl: return "👧"
        case .other: return "🧒"
        }
    }
}

// MARK: - Mock 数据
extension Child {
    static let mock = Child(
        id: "child_001",
        name: "小豆豆",
        gender: .boy,
        birthDate: Calendar.current.date(byAdding: .year, value: -5, to: Date()) ?? Date(),
        avatarEmoji: "🦁",
        favoriteThemes: ["animals", "adventure", "magic"],
        createdAt: Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date()
    )

    static let mockGirl = Child(
        id: "child_002",
        name: "小月亮",
        gender: .girl,
        birthDate: Calendar.current.date(byAdding: .year, value: -4, to: Date()) ?? Date(),
        avatarEmoji: "🦄",
        favoriteThemes: ["magic", "friendship", "family"],
        createdAt: Date()
    )
}
