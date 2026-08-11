//
//  AIStoryRequest.swift
//  MamaBabaStories
//
//  AI 故事生成请求模型
//

import Foundation

// MARK: - AI 故事生成请求
struct AIStoryRequest: Codable {
    let theme: String
    let characters: [String]
    let style: String
    let targetAge: String
    let wordCount: Int
    let customPrompt: String?
    let childName: String?
    let includeMorals: Bool
    let language: String

    init(
        theme: String,
        characters: [String],
        style: String,
        targetAge: String,
        wordCount: Int = 500,
        customPrompt: String? = nil,
        childName: String? = nil,
        includeMorals: Bool = true
    ) {
        self.theme = theme
        self.characters = characters
        self.style = style
        self.targetAge = targetAge
        self.wordCount = wordCount
        self.customPrompt = customPrompt
        self.childName = childName
        self.includeMorals = includeMorals
        self.language = "zh-CN"
    }
}

// MARK: - AI 故事生成响应
struct AIStoryResponse: Codable {
    let storyId: String
    let title: String
    let content: String
    let summary: String
    let wordCount: Int
    let suggestedDuration: TimeInterval
    let tags: [String]
    let characters: [String]
    let coverEmoji: String
    let coverGradient: [String]
    let createdAt: Date
}

// MARK: - 故事生成状态
enum StoryGenerationStatus: String, Codable {
    case pending = "pending"
    case generating = "generating"
    case synthesizing = "synthesizing"
    case completed = "completed"
    case failed = "failed"
}

// MARK: - 故事生成进度
struct StoryGenerationProgress: Codable {
    let requestId: String
    let status: StoryGenerationStatus
    let progress: Double  // 0-1
    let stage: String?
    let estimatedTimeRemaining: TimeInterval?
    let error: String?
}

// MARK: - TTS 合成请求
struct TTSSynthesisRequest: Codable {
    let storyId: String
    let voiceModelId: String
    let speed: Float?
    let pitch: Float?
    let emotion: String?
    let stream: Bool

    init(storyId: String, voiceModelId: String, speed: Float? = nil, pitch: Float? = nil, emotion: String? = "warm", stream: Bool = true) {
        self.storyId = storyId
        self.voiceModelId = voiceModelId
        self.speed = speed
        self.pitch = pitch
        self.emotion = emotion
        self.stream = stream
    }
}

// MARK: - TTS 合成响应
struct TTSSynthesisResponse: Codable {
    let taskId: String
    let status: String
    let audioUrl: String?
    let duration: TimeInterval?
    let progress: Double?
}

// MARK: - 字数选项
enum WordCountOption: Int, CaseIterable, Identifiable {
    case short_300 = 300
    case medium_500 = 500
    case long_800 = 800
    case extraLong_1200 = 1200

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .short_300: return "短篇（约300字）"
        case .medium_500: return "中篇（约500字）"
        case .long_800: return "长篇（约800字）"
        case .extraLong_1200: return "超长篇（约1200字）"
        }
    }

    var estimatedDuration: TimeInterval {
        // 假设每分钟说150字
        return Double(rawValue) / 150.0 * 60.0
    }
}

// MARK: - 情感选项
enum TTSemotion: String, CaseIterable, Codable, Identifiable {
    case warm = "温暖"
    case cheerful = "欢快"
    case gentle = "温柔"
    case exciting = "激动"
    case calm = "平静"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .warm: return "☀️"
        case .cheerful: return "🎉"
        case .gentle: return "🌸"
        case .exciting: return "⚡"
        case .calm: return "🌙"
        }
    }
}
