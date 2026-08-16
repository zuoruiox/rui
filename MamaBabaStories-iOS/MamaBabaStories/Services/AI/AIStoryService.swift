//
//  AIStoryService.swift
//  MamaBabaStories
//
//  AI 故事生成服务 - 基于 LLM API
//

import Foundation

// MARK: - AI 故事服务协议
protocol AIStoryServiceProtocol {
    func generateStory(request: AIStoryRequest) async throws -> AIStoryResponse
    func pollGenerationStatus(requestId: String) async throws -> StoryGenerationProgress
    func regenerateStory(storyId: String) async throws -> AIStoryResponse
    func editStory(storyId: String, edits: String) async throws -> AIStoryResponse
    func saveStory(_ story: AIStoryResponse, editedContent: String, audioURL: String?, theme: String, style: String, targetAgeGroup: String, voiceModelId: String?, voiceModelName: String?) async throws -> Story
}

// MARK: - AIStoryService 实现
class AIStoryService: AIStoryServiceProtocol {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    // MARK: - 生成故事
    func generateStory(request: AIStoryRequest) async throws -> AIStoryResponse {
        Logger.info("开始生成故事: 主题=\(request.theme), 风格=\(request.style)", category: .ai)

        let response: AIStoryResponse = try await apiClient.request(.generateStory(request: request))
        Logger.info("故事生成完成: \(response.title), 字数=\(response.wordCount)", category: .ai)
        return response
    }

    // MARK: - 轮询生成状态
    func pollGenerationStatus(requestId: String) async throws -> StoryGenerationProgress {
        return try await apiClient.request(.getGenerationStatus(requestId: requestId))
    }

    // MARK: - 重新生成
    func regenerateStory(storyId: String) async throws -> AIStoryResponse {
        Logger.info("重新生成故事: \(storyId)", category: .ai)
        return try await apiClient.request(.regenerateStory(storyId: storyId))
    }

    // MARK: - 编辑故事
    func editStory(storyId: String, edits: String) async throws -> AIStoryResponse {
        Logger.info("编辑故事: \(storyId), 修改要求: \(edits)", category: .ai)
        return try await apiClient.request(.editStory(id: storyId, edits: edits))
    }

    // MARK: - 保存故事到服务器
    func saveStory(_ aiStory: AIStoryResponse, editedContent: String, audioURL: String?, theme: String, style: String, targetAgeGroup: String, voiceModelId: String?, voiceModelName: String?) async throws -> Story {
        Logger.info("保存故事到服务器: \(aiStory.title)", category: .ai)

        let wordCount = editedContent.replacingOccurrences(of: "\\s", with: "", options: .regularExpression).count

        // 将数组序列化为 JSON 字符串（服务器存储为 String 类型）
        let tagsJSON = try? JSONSerialization.data(withJSONObject: aiStory.tags)
        let tagsString = tagsJSON.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        let charsJSON = try? JSONSerialization.data(withJSONObject: aiStory.characters)
        let charsString = charsJSON.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        // coverGradient: 非空数组序列化为 JSON 字符串，空数组传 null
        let gradientString: String?
        if let gradients = aiStory.coverGradient, !gradients.isEmpty {
            let data = try? JSONSerialization.data(withJSONObject: gradients)
            gradientString = data.flatMap { String(data: $0, encoding: .utf8) }
        } else {
            gradientString = nil
        }

        let createRequest = CreateStoryRequest(
            title: aiStory.title,
            content: editedContent,
            summary: aiStory.summary,
            theme: theme,
            style: style,
            targetAgeGroup: targetAgeGroup,
            coverEmoji: aiStory.coverEmoji,
            coverGradient: gradientString,
            audioUrl: audioURL ?? "",
            duration: aiStory.suggestedDuration,
            wordCount: wordCount,
            voiceModelId: voiceModelId ?? "",
            voiceModelName: voiceModelName ?? "",
            isAIGenerated: true,
            tags: tagsString,
            characters: charsString
        )

        let savedStory: Story = try await apiClient.request(.createStoryFull(createRequest))
        Logger.info("故事保存成功: \(savedStory.id)", category: .ai)
        return savedStory
    }
}

// MARK: - Mock AIStoryService
class MockAIStoryService: AIStoryServiceProtocol {
    var mockDelay: TimeInterval = 2.0
    var shouldFail = false

    func generateStory(request: AIStoryRequest) async throws -> AIStoryResponse {
        // 模拟生成延迟
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))

        if shouldFail {
            throw NSError(domain: "AIStory", code: -1, userInfo: [NSLocalizedDescriptionKey: "生成失败，请重试"])
        }

        // 根据主题生成不同的 mock 故事
        let theme = request.theme
        let (title, content, emoji, gradient) = generateMockStory(theme: theme, characters: request.characters, childName: request.childName)

        return AIStoryResponse(
            storyId: "story_ai_\(UUID().uuidString.prefix(8))",
            title: title,
            content: content,
            summary: String(content.prefix(100)) + "...",
            wordCount: content.count,
            suggestedDuration: Double(content.count) / 150.0 * 60.0,
            tags: [request.theme, request.style],
            characters: request.characters,
            coverEmoji: emoji,
            coverGradient: gradient,
            createdAt: Date()
        )
    }

    func pollGenerationStatus(requestId: String) async throws -> StoryGenerationProgress {
        try await Task.sleep(nanoseconds: 500_000_000)
        return StoryGenerationProgress(
            requestId: requestId,
            status: .completed,
            progress: 1.0,
            stage: "completed",
            estimatedTimeRemaining: 0,
            error: nil
        )
    }

    func regenerateStory(storyId: String) async throws -> AIStoryResponse {
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        let (title, content, emoji, gradient) = generateMockStory(theme: "magic", characters: [], childName: nil)
        return AIStoryResponse(
            storyId: storyId,
            title: title + "（新版）",
            content: content,
            summary: String(content.prefix(100)) + "...",
            wordCount: content.count,
            suggestedDuration: 300,
            tags: ["魔法", "冒险"],
            characters: [],
            coverEmoji: emoji,
            coverGradient: gradient,
            createdAt: Date()
        )
    }

    func editStory(storyId: String, edits: String) async throws -> AIStoryResponse {
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        let (title, content, emoji, gradient) = generateMockStory(theme: "adventure", characters: [], childName: nil)
        return AIStoryResponse(
            storyId: storyId,
            title: title,
            content: content + "\n\n（已根据要求修改：\(edits)）",
            summary: String(content.prefix(100)) + "...",
            wordCount: content.count + edits.count,
            suggestedDuration: 320,
            tags: ["修改版"],
            characters: [],
            coverEmoji: emoji,
            coverGradient: gradient,
            createdAt: Date()
        )
    }

    func saveStory(_ aiStory: AIStoryResponse, editedContent: String, audioURL: String?, theme: String, style: String, targetAgeGroup: String, voiceModelId: String?, voiceModelName: String?) async throws -> Story {
        try await Task.sleep(nanoseconds: 500_000_000)
        return Story(
            id: aiStory.storyId,
            title: aiStory.title,
            content: editedContent,
            summary: aiStory.summary,
            theme: theme,
            style: style,
            targetAgeGroup: targetAgeGroup,
            coverImageURL: nil,
            coverGradient: aiStory.coverGradient,
            coverEmoji: aiStory.coverEmoji,
            audioURL: audioURL,
            localAudioPath: nil,
            duration: aiStory.suggestedDuration,
            wordCount: editedContent.count,
            voiceModelId: voiceModelId,
            voiceModelName: voiceModelName,
            isAIGenerated: true,
            isFavorite: false,
            isDownloaded: false,
            playCount: 0,
            createdAt: aiStory.createdAt ?? Date(),
            updatedAt: aiStory.createdAt ?? Date(),
            tags: aiStory.tags,
            characters: aiStory.characters
        )
    }

    // MARK: - 生成 Mock 故事内容
    private func generateMockStory(theme: String, characters: [String], childName: String?) -> (String, String, String, [String]) {
        let name = childName ?? "小朋友"
        let character = characters.first ?? "小精灵"

        switch theme {
        case "adventure":
            return (
                "\(name)的奇妙冒险",
                "在一个阳光明媚的早晨，\(name)发现了一扇神秘的小门。门后是一个五彩斑斓的世界，会说话的\(character)正在等待着它的新朋友。\n\n\"你好呀！\"\(character)开心地说，\"我等你好久了，我们一起去探险吧！\"\n\n他们穿过彩虹桥，爬上云朵山，还遇到了会唱歌的花朵。每一步都充满了惊喜和欢笑。\n\n在探险的路上，\(name)学会了勇敢和坚持。当他们遇到困难时，总是互相帮助，一起克服。\n\n夕阳西下，\(name)带着满满的收获和美好的回忆，回到了温暖的家。这真是一次难忘的冒险啊！",
                "map.fill",
                ["#FFE0B2", "#FFCC80"]
            )
        case "animals":
            return (
                "森林里的好朋友",
                "在美丽的大森林里，住着许多可爱的小动物。有蹦蹦跳跳的小兔子，有机灵的小松鼠，还有憨厚的小熊。\n\n一天，小兔子发现了一片美味的蘑菇地，但它一个人采不完。于是它找来了所有的好朋友。\n\n大家齐心协力，不一会儿就采了满满一篮子蘑菇。晚上，它们一起举办了一场热闹的蘑菇派对。\n\n\(name)也被邀请参加了派对，和小动物们一起唱歌跳舞，度过了快乐的时光。\n\n这个故事告诉我们，好朋友要互相分享，团结起来力量大！",
                "hare.fill",
                ["#C8E6C9", "#A5D6A7"]
            )
        case "bedtime":
            return (
                "晚安，小星星",
                "夜幕降临了，天空中挂满了闪闪发亮的星星。月亮婆婆轻轻地把银色的光芒洒向大地。\n\n\(name)躺在温暖的小床上，听着窗外蟋蟀的歌声。一颗最亮的小星星从窗户飞了进来，停在\(name)的枕边。\n\n\"我来陪你睡觉啦，\"\(character)温柔地说，\"闭上眼睛，我给你讲一个甜甜的梦的故事。\"\n\n小星星讲述着云朵上的城堡、彩虹滑梯和糖果花园。\(name)听着听着，眼皮越来越沉，慢慢进入了甜美的梦乡。\n\n晚安，\(name)。愿你做个好梦，明天又是美好的一天。",
                "moon.stars.fill",
                ["#BBDEFB", "#90CAF9"]
            )
        case "magic":
            return (
                "神奇的魔法花园",
                "在\(name)家的后院里，有一个谁也不知道的秘密——每当月圆之夜，花园里的花朵就会变成小精灵！\n\n这天晚上，\(name)偶然发现了这个秘密。一朵玫瑰花变成了穿着红裙子的\(character)，它手里拿着一根闪闪发光的魔法棒。\n\n\"欢迎来到魔法花园！\"\(character)挥舞着魔法棒，所有的花朵都开始跳舞。\n\n\(name)和花精灵们一起在月光下跳舞、唱歌，还学会了一个小小的魔法——让枯萎的花朵重新绽放。\n\n天亮了，魔法消失了，但\(name)知道，下一个月圆之夜，奇妙的派对还会继续。",
                "sparkles",
                ["#F8BBD0", "#F48FB1"]
            )
        case "friendship":
            return (
                "最好的朋友",
                "\(name)刚搬到新家，一个朋友都不认识，觉得有点孤单。\n\n一天，\(name)在公园里遇到了\(character)。\(character)正在搭积木，但是怎么也搭不好一座高塔。\n\n\"我来帮你吧！\"\(name)主动走过去。两个人一起合作，不一会儿就搭出了一座漂亮的城堡。\n\n从那以后，他们成了最好的朋友。一起画画，一起捉迷藏，一起分享好吃的点心。\n\n\(name)明白了，只要主动伸出友谊的小手，就能找到最好的朋友。友谊是世界上最珍贵的宝藏。",
                "heart.fill",
                ["#FFE0B2", "#FFCC80"]
            )
        case "family":
            return (
                "温暖的家",
                "家是世界上最温暖的地方。在\(name)的家里，有温柔的妈妈、勇敢的爸爸，还有可爱的\(character)。\n\n每天早上，妈妈都会准备香喷喷的早餐。爸爸会给\(name)一个大大的拥抱。晚上，全家人围坐在一起，分享一天中发生的有趣事情。\n\n有一次\(name)生病了，爸爸妈妈整夜守在身边，\(character)也乖乖地趴在床边。在家人的照顾下，\(name)很快就康复了。\n\n\(name)觉得自己是世界上最幸福的孩子，因为有一个充满爱的家。",
                "house.fill",
                ["#FFCCBC", "#FFAB91"]
            )
        case "space":
            return (
                "太空小旅行家",
                "\"五、四、三、二、一，发射！\"\n\n随着一声巨响，\(name)驾驶着小火箭冲上了蓝天，飞向浩瀚的宇宙。\n\n窗外的星星像钻石一样闪闪发光，月亮微笑着向\(name)招手。在火星上，\(name)遇到了外星小朋友\(character)，它有着绿色的皮肤和大大的眼睛。\n\n\(character)带着\(name)参观了火星上的水晶城堡，还一起在土星的光环上滑滑梯。他们成了跨星球的好朋友。\n\n带着外星朋友的礼物和美好的回忆，\(name)驾驶火箭返回了地球。这真是一次不可思议的太空旅行！",
                "moon.stars.fill",
                ["#D1C4E9", "#B39DDB"]
            )
        case "nature":
            return (
                "四季的礼物",
                "春天，\(name)和\(character)一起在花园里种下了一颗小种子。他们每天浇水、施肥，期待着种子发芽。\n\n夏天，种子长成了一棵大树，茂密的枝叶像一把大伞。\(name)在树下乘凉，听蝉儿唱歌。\n\n秋天，树上结满了红彤彤的果实。\(name)和\(character)一起采摘水果，分享给森林里的小动物们。\n\n冬天，大雪覆盖了大地，大树穿上了雪白的棉袄。\(name)在树下堆雪人，等待着春天的到来。\n\n大自然给了我们最美好的礼物，我们要好好爱护它。",
                "leaf.fill",
                ["#C8E6C9", "#A5D6A7"]
            )
        case "courage":
            return (
                "勇敢的小英雄",
                "森林里传来了消息：通往山谷的小桥被暴风雨冲断了，小动物们都没法过河去参加丰收节了。\n\n\(name)虽然有点害怕，但还是决定想办法帮助大家。\(character)也来帮忙了。\n\n他们找来了木头和绳子，一次又一次地尝试。虽然失败了好几次，但\(name)没有放弃。\n\n终于，在大家的帮助下，一座新桥建好了！小动物们欢呼着过了桥，丰收节如期举行。\n\n大家都夸\(name)是个勇敢的小英雄。\(name)明白了，勇敢不是不害怕，而是虽然害怕但依然去做正确的事。",
                "shield.fill",
                ["#FFE0B2", "#FFCC80"]
            )
        case "kindness":
            return (
                "善良的小天使",
                "\(name)有一颗善良的心，总是愿意帮助别人。\n\n看到老奶奶过马路，\(name)会主动扶着她。看到小朋友摔倒了，\(name)会把他扶起来。看到流浪的小猫，\(name)会给它喂食物。\n\n一天，\(name)在森林里发现了一只受伤的小鸟。\(name)小心翼翼地把它带回家，给它包扎伤口，喂它吃东西。\n\n在\(name)的细心照顾下，小鸟很快康复了。小鸟飞走之前，留下了一片金色的羽毛作为感谢。\n\n\(character)告诉\(name)，善良就像一颗种子，种在心里会长出美丽的花朵，让世界变得更加美好。",
                "heart.fill",
                ["#F8BBD0", "#F48FB1"]
            )
        default:
            return (
                "\(name)的奇妙冒险",
                "在一个阳光明媚的早晨，\(name)发现了一扇神秘的小门...",
                "book.fill",
                ["#FFE0B2", "#FFCC80"]
            )
        }
    }
}
