//
//  VoiceModel.swift
//  MamaBabaStories
//
//  声音模型数据模型
//

import Foundation

// MARK: - 声音模型
struct VoiceModel: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let ownerType: String
    let emoji: String?
    let status: String
    let progress: Float
    let quality: String?
    let previewUrl: String?
    let errorMessage: String?
    let trainedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?
    let userId: String?
    let modelPath: String?
    let count: RecordingCount?

    // 后端返回的嵌套 _count 对象
    struct RecordingCount: Codable, Hashable {
        let recordings: Int?
    }

    // 兼容旧 UI 的计算属性
    var ownerTypeEnum: VoiceOwnerType {
        VoiceOwnerType(rawValue: ownerType) ?? .other
    }

    var ownerName: String {
        ownerTypeEnum.displayName
    }

    var statusEnum: VoiceModelStatus {
        VoiceModelStatus(rawValue: status) ?? .draft
    }

    var trainingProgress: Double {
        Double(progress)
    }

    var sampleCount: Int {
        count?.recordings ?? 0
    }

    var durationSeconds: Double { 0 }
    var coverColor: String? { nil }
    var lastUsedAt: Date? { nil }
    var isDefault: Bool { false }
    var displayName: String { name }

    var formattedDuration: String {
        let minutes = Int(durationSeconds) / 60
        let seconds = Int(durationSeconds) % 60
        return String(format: "%d分%02d秒", minutes, seconds)
    }

    var statusDescription: String {
        switch statusEnum {
        case .draft: return "待录制"
        case .recording: return "录制中"
        case .training: return "训练中"
        case .ready: return "可用"
        case .failed: return "训练失败"
        }
    }

    // 普通初始化方法（用于 Mock 和本地创建）
    init(id: String, name: String, ownerType: String, emoji: String? = nil, status: String,
         progress: Float, quality: String? = nil, previewUrl: String? = nil,
         errorMessage: String? = nil, trainedAt: Date? = nil, createdAt: Date? = nil,
         updatedAt: Date? = nil, recordingsCount: Int? = nil) {
        self.id = id
        self.name = name
        self.ownerType = ownerType
        self.emoji = emoji
        self.status = status
        self.progress = progress
        self.quality = quality
        self.previewUrl = previewUrl
        self.errorMessage = errorMessage
        self.trainedAt = trainedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.userId = nil
        self.modelPath = nil
        self.count = recordingsCount.map { RecordingCount(recordings: $0) }
    }

    // 自定义解码，容错处理后端可能返回的额外字段
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)

        func key(_ s: String) -> DynamicCodingKey { DynamicCodingKey(stringValue: s) }

        id = try container.decode(String.self, forKey: key("id"))
        name = try container.decode(String.self, forKey: key("name"))
        ownerType = (try? container.decode(String.self, forKey: key("ownerType"))) ?? "other"
        emoji = try? container.decodeIfPresent(String.self, forKey: key("emoji")) ?? nil
        status = (try? container.decode(String.self, forKey: key("status"))) ?? "draft"
        progress = (try? container.decode(Float.self, forKey: key("progress"))) ?? 0
        quality = try? container.decodeIfPresent(String.self, forKey: key("quality")) ?? nil
        previewUrl = try? container.decodeIfPresent(String.self, forKey: key("previewUrl"))
        errorMessage = try? container.decodeIfPresent(String.self, forKey: key("errorMessage"))
        trainedAt = container.decodeDateIfPresent(forKey: "trainedAt")
        createdAt = container.decodeDateIfPresent(forKey: "createdAt")
        updatedAt = container.decodeDateIfPresent(forKey: "updatedAt")
        userId = try? container.decodeIfPresent(String.self, forKey: key("userId"))
        modelPath = try? container.decodeIfPresent(String.self, forKey: key("modelPath"))
        count = try? container.decodeIfPresent(RecordingCount.self, forKey: key("_count"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        func key(_ s: String) -> DynamicCodingKey { DynamicCodingKey(stringValue: s) }
        try container.encode(id, forKey: key("id"))
        try container.encode(name, forKey: key("name"))
        try container.encode(ownerType, forKey: key("ownerType"))
        try container.encodeIfPresent(emoji, forKey: key("emoji"))
        try container.encode(status, forKey: key("status"))
        try container.encode(progress, forKey: key("progress"))
        try container.encodeIfPresent(quality, forKey: key("quality"))
        try container.encodeIfPresent(previewUrl, forKey: key("previewUrl"))
        try container.encodeIfPresent(errorMessage, forKey: key("errorMessage"))
        try container.encodeIfPresent(trainedAt, forKey: key("trainedAt"))
        try container.encodeIfPresent(createdAt, forKey: key("createdAt"))
        try container.encodeIfPresent(updatedAt, forKey: key("updatedAt"))
        try container.encodeIfPresent(userId, forKey: key("userId"))
        try container.encodeIfPresent(modelPath, forKey: key("modelPath"))
        try container.encodeIfPresent(count, forKey: key("_count"))
    }
}

// MARK: - 动态 CodingKey（支持任意字段名）
struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { self.intValue = intValue; self.stringValue = "\(intValue)" }
}

// MARK: - KeyedDecodingContainer 扩展：日期容错解码
extension KeyedDecodingContainer where Key == DynamicCodingKey {
    func decodeDateIfPresent(forKey key: String) -> Date? {
        let k = DynamicCodingKey(stringValue: key)
        // 尝试 Date 类型
        if let d = try? decodeIfPresent(Date.self, forKey: k) { return d }
        // 尝试 String 类型并解析
        if let s = try? decodeIfPresent(String.self, forKey: k), let date = ISO8601DateParser.parse(s) {
            return date
        }
        return nil
    }
}

// MARK: - ISO8601 日期解析
enum ISO8601DateParser {
    static let formatters: [ISO8601DateFormatter] = {
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        return [f1, f2]
    }()

    static func parse(_ string: String) -> Date? {
        for f in formatters {
            if let d = f.date(from: string) { return d }
        }
        return nil
    }
}

// MARK: - 声音归属类型
enum VoiceOwnerType: String, Codable, CaseIterable, Identifiable {
    case mom = "mom"
    case dad = "dad"
    case grandma = "grandma"
    case grandpa = "grandpa"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mom: return "妈妈"
        case .dad: return "爸爸"
        case .grandma: return "奶奶"
        case .grandpa: return "爷爷"
        case .other: return "其他"
        }
    }

    var emoji: String {
        switch self {
        case .mom: return "👩"
        case .dad: return "👨"
        case .grandma: return "👵"
        case .grandpa: return "👴"
        case .other: return "🧑"
        }
    }

    var defaultName: String {
        return displayName + "的声音"
    }
}

// MARK: - 声音模型状态
enum VoiceModelStatus: String, Codable {
    case draft = "draft"
    case recording = "recording"
    case training = "training"
    case ready = "ready"
    case failed = "failed"

    var displayText: String {
        switch self {
        case .draft: return "待录制"
        case .recording: return "录制中"
        case .training: return "训练中"
        case .ready: return "已就绪"
        case .failed: return "训练失败"
        }
    }
}

// MARK: - 录音样本
struct RecordingSample: Codable, Identifiable {
    let id: String
    let voiceModelId: String?
    let filePath: String?
    let duration: Float?
    let fileSize: Int?
    let quality: String?
    let promptText: String?
    let sortOrder: Int?
    let createdAt: Date?

    var localURL: URL? { nil }
    var remoteURL: String? { filePath }
    var isUploaded: Bool { true }
    var uploadProgress: Double { 1.0 }
    var durationTimeInterval: TimeInterval { TimeInterval(duration ?? 0) }
    var fileSizeInt64: Int64 { Int64(fileSize ?? 0) }
    var qualityObj: RecordingQuality? { nil }

    // 本地初始化
    init(id: String, voiceModelId: String, filePath: String, duration: Float?,
         fileSize: Int?, quality: String?, promptText: String?, sortOrder: Int?, createdAt: Date?) {
        self.id = id
        self.voiceModelId = voiceModelId
        self.filePath = filePath
        self.duration = duration
        self.fileSize = fileSize
        self.quality = quality
        self.promptText = promptText
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }

    // 自定义解码容错
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        func key(_ s: String) -> DynamicCodingKey { DynamicCodingKey(stringValue: s) }

        id = try container.decode(String.self, forKey: key("id"))
        voiceModelId = try? container.decodeIfPresent(String.self, forKey: key("voiceModelId"))
        filePath = try? container.decodeIfPresent(String.self, forKey: key("filePath"))
        duration = try? container.decodeIfPresent(Float.self, forKey: key("duration"))
        fileSize = try? container.decodeIfPresent(Int.self, forKey: key("fileSize"))
        quality = try? container.decodeIfPresent(String.self, forKey: key("quality"))
        promptText = try? container.decodeIfPresent(String.self, forKey: key("promptText"))
        sortOrder = try? container.decodeIfPresent(Int.self, forKey: key("sortOrder"))
        var created: Date? = nil
        if let s = try? container.decodeIfPresent(String.self, forKey: key("createdAt")),
           let d = ISO8601DateParser.parse(s) {
            created = d
        }
        createdAt = created
    }
}

// MARK: - 录音质量（本地使用）
struct RecordingQuality: Codable {
    let snr: Double
    let peakLevel: Float
    let hasClipping: Bool
    let isTooQuiet: Bool
    let isTooLoud: Bool
    let overallScore: Double

    var isPassing: Bool {
        return !hasClipping && !isTooQuiet && !isTooLoud && overallScore >= 60
    }

    var qualityLevel: QualityLevel {
        if overallScore >= 85 { return .excellent }
        if overallScore >= 70 { return .good }
        if overallScore >= 60 { return .acceptable }
        return .poor
    }
}

enum QualityLevel: String, Codable {
    case excellent = "优秀"
    case good = "良好"
    case acceptable = "可用"
    case poor = "较差"

    var color: String {
        switch self {
        case .excellent: return "#4CAF50"
        case .good: return "#8BC34A"
        case .acceptable: return "#FFC107"
        case .poor: return "#F44336"
        }
    }
}

// MARK: - 录音提示文本
struct RecordingPrompt: Identifiable {
    let id: Int
    let text: String
    let category: PromptCategory
    let estimatedDuration: TimeInterval
}

enum PromptCategory: String, CaseIterable {
    case warm = "温馨"
    case story = "故事"
    case daily = "日常"
    case poem = "诗歌"
}

// MARK: - 上传录音响应
struct UploadRecordingResponse: Codable {
    let recording: RecordingSample
    let progress: Float?
    let recordedCount: Int?
    let requiredCount: Int?
}

// MARK: - Mock 数据
extension VoiceModel {
    static let mockMom = VoiceModel(
        id: "voice_001",
        name: "妈妈的声音",
        ownerType: "mom",
        emoji: "👩",
        status: "ready",
        progress: 1.0,
        quality: "quick",
        previewUrl: nil,
        errorMessage: nil,
        trainedAt: Date(),
        createdAt: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(),
        updatedAt: Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date(),
        recordingsCount: 5
    )

    static let mockDad = VoiceModel(
        id: "voice_002",
        name: "爸爸的声音",
        ownerType: "dad",
        emoji: "👨",
        status: "ready",
        progress: 1.0,
        quality: "quick",
        previewUrl: nil,
        errorMessage: nil,
        trainedAt: Date(),
        createdAt: Calendar.current.date(byAdding: .day, value: -15, to: Date()) ?? Date(),
        updatedAt: Calendar.current.date(byAdding: .day, value: -13, to: Date()) ?? Date(),
        recordingsCount: 3
    )

    static let mockTraining = VoiceModel(
        id: "voice_003",
        name: "奶奶的声音",
        ownerType: "grandma",
        emoji: "👵",
        status: "training",
        progress: 0.6,
        quality: "quick",
        previewUrl: nil,
        errorMessage: nil,
        trainedAt: nil,
        createdAt: Date(),
        updatedAt: Date(),
        recordingsCount: 4
    )
}

extension RecordingPrompt {
    static let prompts: [RecordingPrompt] = [
        RecordingPrompt(id: 1, text: "从前有一只可爱的小兔子，住在森林深处的蘑菇房子里。每天清晨，它都会蹦蹦跳跳地去森林里采蘑菇。", category: .story, estimatedDuration: 15),
        RecordingPrompt(id: 2, text: "宝贝，妈妈爱你。今天你在学校过得开心吗？有没有交到新朋友？晚上想吃什么好吃的呀？", category: .daily, estimatedDuration: 12),
        RecordingPrompt(id: 3, text: "月亮悄悄地爬上了树梢，星星在夜空中眨着眼睛。小宝宝躺在温暖的小床上，听着妈妈讲的故事，慢慢进入了甜甜的梦乡。", category: .warm, estimatedDuration: 18),
        RecordingPrompt(id: 4, text: "春眠不觉晓，处处闻啼鸟。夜来风雨声，花落知多少。", category: .poem, estimatedDuration: 10),
        RecordingPrompt(id: 5, text: "在蔚蓝的大海里，住着一条五颜六色的小鱼。它有一个梦想，就是游到大海的尽头，去看看那里有什么奇妙的景色。", category: .story, estimatedDuration: 16),
        RecordingPrompt(id: 6, text: "亲爱的宝贝，你是爸爸妈妈最珍贵的礼物。看着你一天天长大，学会新本领，我们心里充满了幸福和骄傲。", category: .warm, estimatedDuration: 15),
        RecordingPrompt(id: 7, text: "今天天气真好，阳光明媚，小鸟在枝头唱歌。小朋友们在公园里开心地玩耍，有的在滑滑梯，有的在荡秋千。", category: .daily, estimatedDuration: 14),
        RecordingPrompt(id: 8, text: "床前明月光，疑是地上霜。举头望明月，低头思故乡。", category: .poem, estimatedDuration: 10),
        RecordingPrompt(id: 9, text: "小熊今天过生日，它邀请了所有的好朋友来参加生日派对。大家带来了精美的礼物，一起唱生日歌，吃美味的蛋糕。", category: .story, estimatedDuration: 17),
        RecordingPrompt(id: 10, text: "天黑了，该睡觉了。闭上眼睛，盖好被子，做一个美美的梦。明天早上醒来，又是充满快乐的一天。晚安，我的小宝贝。", category: .warm, estimatedDuration: 16),
    ]
}
