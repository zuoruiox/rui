//
//  Story.swift
//  MamaBabaStories
//
//  故事数据模型
//

import Foundation

// MARK: - 故事模型
struct Story: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let content: String
    let summary: String?
    let theme: String
    let style: String
    let targetAgeGroup: String
    let coverImageURL: String?
    let coverGradient: [String]?
    let coverEmoji: String
    let audioURL: String?
    var localAudioPath: String?
    let duration: TimeInterval
    let wordCount: Int
    let voiceModelId: String?
    let voiceModelName: String?
    let isAIGenerated: Bool
    var isFavorite: Bool
    var isDownloaded: Bool
    let playCount: Int
    let createdAt: Date
    let updatedAt: Date
    let tags: [String]
    let characters: [String]?
    let status: String?
    let isPremium: Bool
    let categoryId: String?

    enum CodingKeys: String, CodingKey {
        case id, title, content, summary, theme, style, targetAgeGroup
        case coverImageURL = "coverImageUrl"
        case coverGradient, coverEmoji
        case audioURL = "audioUrl"
        case localAudioPath
        case duration, wordCount, voiceModelId, voiceModelName
        case isAIGenerated, isFavorite = "isFavorited", isDownloaded, playCount
        case createdAt, updatedAt, tags, characters, status, isPremium, categoryId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        theme = try container.decode(String.self, forKey: .theme)
        style = try container.decode(String.self, forKey: .style)
        targetAgeGroup = try container.decode(String.self, forKey: .targetAgeGroup)
        coverImageURL = try container.decodeIfPresent(String.self, forKey: .coverImageURL)
        // 解析 coverGradient: 可能是数组或 JSON 字符串
        if let gradientArray = try? container.decode([String].self, forKey: .coverGradient) {
            coverGradient = gradientArray
        } else if let gradientString = try? container.decode(String.self, forKey: .coverGradient) {
            if let data = gradientString.data(using: .utf8),
               let array = try? JSONDecoder().decode([String].self, from: data) {
                coverGradient = array
            } else {
                coverGradient = nil
            }
        } else {
            coverGradient = nil
        }
        coverEmoji = try container.decodeIfPresent(String.self, forKey: .coverEmoji) ?? "book.fill"
        audioURL = try container.decodeIfPresent(String.self, forKey: .audioURL)
        localAudioPath = try container.decodeIfPresent(String.self, forKey: .localAudioPath)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 0
        wordCount = try container.decodeIfPresent(Int.self, forKey: .wordCount) ?? 0
        voiceModelId = try container.decodeIfPresent(String.self, forKey: .voiceModelId)
        voiceModelName = try container.decodeIfPresent(String.self, forKey: .voiceModelName)
        isAIGenerated = try container.decodeIfPresent(Bool.self, forKey: .isAIGenerated) ?? false
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        isDownloaded = false
        playCount = try container.decodeIfPresent(Int.self, forKey: .playCount) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        status = try container.decodeIfPresent(String.self, forKey: .status)
        isPremium = try container.decodeIfPresent(Bool.self, forKey: .isPremium) ?? false
        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)

        // 解析 tags: 可能是 JSON 字符串或数组
        if let tagsArray = try? container.decode([String].self, forKey: .tags) {
            tags = tagsArray
        } else if let tagsString = try? container.decode(String.self, forKey: .tags) {
            if let data = tagsString.data(using: .utf8),
               let array = try? JSONDecoder().decode([String].self, from: data) {
                tags = array
            } else {
                tags = tagsString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            }
        } else {
            tags = []
        }

        // 解析 characters
        if let charsArray = try? container.decode([String].self, forKey: .characters) {
            characters = charsArray
        } else if let charsString = try? container.decode(String.self, forKey: .characters) {
            if let data = charsString.data(using: .utf8),
               let array = try? JSONDecoder().decode([String].self, from: data) {
                characters = array
            } else {
                characters = charsString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            }
        } else {
            characters = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encode(theme, forKey: .theme)
        try container.encode(style, forKey: .style)
        try container.encode(targetAgeGroup, forKey: .targetAgeGroup)
        try container.encodeIfPresent(coverImageURL, forKey: .coverImageURL)
        try container.encodeIfPresent(coverGradient, forKey: .coverGradient)
        try container.encode(coverEmoji, forKey: .coverEmoji)
        try container.encodeIfPresent(audioURL, forKey: .audioURL)
        try container.encodeIfPresent(localAudioPath, forKey: .localAudioPath)
        try container.encode(duration, forKey: .duration)
        try container.encode(wordCount, forKey: .wordCount)
        try container.encodeIfPresent(voiceModelId, forKey: .voiceModelId)
        try container.encodeIfPresent(voiceModelName, forKey: .voiceModelName)
        try container.encode(isAIGenerated, forKey: .isAIGenerated)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(isDownloaded, forKey: .isDownloaded)
        try container.encode(playCount, forKey: .playCount)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encode(isPremium, forKey: .isPremium)
        try container.encodeIfPresent(categoryId, forKey: .categoryId)
        try container.encode(tags, forKey: .tags)
        try container.encodeIfPresent(characters, forKey: .characters)
    }

    // 用于本地创建副本的 init
    init(id: String, title: String, content: String, summary: String?, theme: String, style: String,
         targetAgeGroup: String, coverImageURL: String?, coverGradient: [String]?, coverEmoji: String,
         audioURL: String?, localAudioPath: String?, duration: TimeInterval, wordCount: Int,
         voiceModelId: String?, voiceModelName: String?, isAIGenerated: Bool, isFavorite: Bool,
         isDownloaded: Bool, playCount: Int, createdAt: Date, updatedAt: Date,
         tags: [String], characters: [String]?) {
        self.id = id
        self.title = title
        self.content = content
        self.summary = summary
        self.theme = theme
        self.style = style
        self.targetAgeGroup = targetAgeGroup
        self.coverImageURL = coverImageURL
        self.coverGradient = coverGradient
        self.coverEmoji = coverEmoji
        self.audioURL = audioURL
        self.localAudioPath = localAudioPath
        self.duration = duration
        self.wordCount = wordCount
        self.voiceModelId = voiceModelId
        self.voiceModelName = voiceModelName
        self.isAIGenerated = isAIGenerated
        self.isFavorite = isFavorite
        self.isDownloaded = isDownloaded
        self.playCount = playCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
        self.characters = characters
        self.status = nil
        self.isPremium = false
        self.categoryId = nil
    }

    // 格式化时长
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes == 0 {
            return "\(seconds)秒"
        }
        return "\(minutes)分\(seconds)秒"
    }

    // 字数描述
    var wordCountText: String {
        if wordCount >= 1000 {
            return String(format: "%.1f千字", Double(wordCount) / 1000.0)
        }
        return "\(wordCount)字"
    }

    // 是否有音频
    var hasAudio: Bool {
        audioURL != nil || localAudioPath != nil
    }

    // 音频是否可用（本地或远程）
    var isAudioAvailable: Bool {
        if localAudioPath != nil { return true }
        if let url = audioURL, !url.isEmpty { return true }
        return false
    }

    // 主题显示名（英文 key 转中文）
    var themeDisplayName: String {
        let themeMap: [String: String] = [
            "adventure": "冒险",
            "friendship": "友谊",
            "family": "家庭",
            "animals": "动物",
            "magic": "魔法",
            "space": "太空",
            "nature": "自然",
            "bedtime": "睡前",
            "courage": "勇气",
            "kindness": "善良"
        ]
        return themeMap[theme] ?? theme
    }
}

// MARK: - 故事分类
struct StoryCategory: Identifiable {
    let id: String
    let name: String
    let icon: String
    let theme: String?
    let stories: [Story]?
}

// MARK: - 播放列表
struct Playlist: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let coverEmoji: String
    var storyIds: [String]
    let createdAt: Date
    var updatedAt: Date

    var storyCount: Int { storyIds.count }
}

// MARK: - 播放历史记录
struct PlayHistory: Codable, Identifiable {
    let id: String
    let storyId: String
    let story: Story?
    let voiceModelId: String?
    var position: TimeInterval
    var duration: TimeInterval
    let playedAt: Date
    var completed: Bool

    // 播放进度百分比
    var progressPercent: Double {
        guard duration > 0 else { return 0 }
        return min(position / duration, 1.0)
    }
}

// MARK: - Mock 数据
extension Story {
    static let mockStories: [Story] = [
        Story(
            id: "story_001",
            title: "小兔子的冒险之旅",
            content: "从前，在一片美丽的大森林里，住着一只名叫白白的小兔子。白白有一身雪白的毛，两只长长的耳朵，还有一双红宝石般的眼睛。\n\n有一天，白白决定去森林深处探险。妈妈叮嘱它说：\"白白，要小心哦，记得在太阳落山前回家。\"白白点点头，蹦蹦跳跳地出发了。\n\n一路上，白白遇到了许多好朋友。小松鼠在树上向它招手，小鹿在溪边喝水，蝴蝶在花丛中翩翩起舞。白白开心极了，它从来没有来过这么远的地方。\n\n突然，天空乌云密布，下起了大雨。白白赶紧跑到一棵大树下躲雨。这时候，它发现一只小刺猬被困在雨中，浑身发抖。白白毫不犹豫地把自己的大叶子伞递给了小刺猬。\n\n雨停了，太阳出来了，天空中出现了一道美丽的彩虹。小刺猬感激地说：\"谢谢你，小兔子！你真是个好孩子。\"白白不好意思地笑了。\n\n回到家后，白白把今天的经历告诉了妈妈。妈妈温柔地摸了摸它的头说：\"我们的白白长大了，不仅勇敢，还很有爱心呢！\"\n\n晚上，白白做了一个甜甜的梦，梦见自己和森林里所有的小动物一起，在彩虹下快乐地玩耍。",
            summary: "勇敢的小兔子白白在森林探险中帮助了小刺猬，学会了勇敢和友爱的故事。",
            theme: "冒险",
            style: "温馨",
            targetAgeGroup: "4-5岁",
            coverImageURL: nil,
            coverGradient: ["#FFE0B2", "#FFCC80"],
            coverEmoji: "hare.fill",
            audioURL: "https://example.com/audio/story_001.mp3",
            localAudioPath: nil,
            duration: 360,
            wordCount: 480,
            voiceModelId: "voice_001",
            voiceModelName: "妈妈的声音",
            isAIGenerated: false,
            isFavorite: true,
            isDownloaded: false,
            playCount: 12,
            createdAt: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
            updatedAt: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
            tags: ["兔子", "森林", "冒险", "友爱"],
            characters: ["白白", "小松鼠", "小鹿", "小刺猬"]
        ),
        Story(
            id: "story_002",
            title: "月亮上的小星星",
            content: "在遥远的夜空中，有一颗特别小的星星，它叫闪闪。闪闪比其他星星都小，发出的光也很微弱。\n\n闪闪总是很自卑，它问月亮妈妈：\"妈妈，为什么我这么小？别的星星都比我亮。\"月亮妈妈笑着说：\"每个星星都有自己的光芒，只是你还没发现而已。\"\n\n一天晚上，闪闪看到地面上有一个小女孩坐在窗边哭泣。原来小女孩怕黑，不敢一个人睡觉。闪闪决定帮助她。\n\n虽然闪闪的光很微弱，但它努力地闪烁着，把温柔的光芒洒在小女孩的窗前。小女孩看到了这颗小星星，觉得它就像一盏小夜灯，温暖又可爱。\n\n\"小星星，你真好！\"小女孩微笑着，慢慢进入了梦乡。\n\n从那以后，闪闪每天晚上都会来到小女孩的窗前，用自己微弱但温暖的光芒陪伴她。闪闪终于明白了，光芒不在于有多亮，而在于是否能温暖别人的心。",
            summary: "小星星闪闪用自己微弱的光芒陪伴怕黑的小女孩，明白了温暖他人的意义。",
            theme: "睡前",
            style: "诗意优美",
            targetAgeGroup: "2-3岁",
            coverImageURL: nil,
            coverGradient: ["#BBDEFB", "#90CAF9"],
            coverEmoji: "star.fill",
            audioURL: "https://example.com/audio/story_002.mp3",
            localAudioPath: nil,
            duration: 280,
            wordCount: 380,
            voiceModelId: "voice_001",
            voiceModelName: "妈妈的声音",
            isAIGenerated: true,
            isFavorite: true,
            isDownloaded: true,
            playCount: 25,
            createdAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
            updatedAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
            tags: ["星星", "月亮", "睡前", "勇气"],
            characters: ["闪闪", "月亮妈妈", "小女孩"]
        ),
        Story(
            id: "story_003",
            title: "勇敢的小火车",
            content: "在山的那边，有一辆蓝色的小火车，它叫嘟嘟。嘟嘟每天都要拉着货物翻过高高的大山，送到山那边的小镇。\n\n有一天，山里下起了大雪，铁轨被厚厚的雪覆盖了。其他火车都说：\"这么大的雪，我们过不去了。\"但是嘟嘟想到山那边的小朋友们正等着圣诞礼物，它决定试一试。\n\n\"我能做到！我能做到！\"嘟嘟一边给自己打气，一边慢慢地向前开。雪花打在它的脸上，寒风呼呼地吹，但嘟嘟没有放弃。\n\n它小心翼翼地爬过山坡，穿过隧道，终于在圣诞节的清晨到达了小镇。小朋友们看到满载礼物的小火车，都欢呼起来。\n\n嘟嘟虽然很累，但它心里暖洋洋的。它明白了，只要有勇气和决心，就没有克服不了的困难。",
            summary: "蓝色小火车嘟嘟冒着大雪为小朋友们送圣诞礼物，展现了勇气和坚持的力量。",
            theme: "勇气",
            style: "童话",
            targetAgeGroup: "6-8岁",
            coverImageURL: nil,
            coverGradient: ["#C5CAE9", "#9FA8DA"],
            coverEmoji: "train.side.front.car",
            audioURL: "https://example.com/audio/story_003.mp3",
            localAudioPath: nil,
            duration: 320,
            wordCount: 420,
            voiceModelId: "voice_002",
            voiceModelName: "爸爸的声音",
            isAIGenerated: false,
            isFavorite: false,
            isDownloaded: false,
            playCount: 8,
            createdAt: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date(),
            updatedAt: Calendar.current.date(byAdding: .day, value: -8, to: Date()) ?? Date(),
            tags: ["火车", "勇气", "坚持", "圣诞"],
            characters: ["嘟嘟"]
        ),
        Story(
            id: "story_004",
            title: "小熊找朋友",
            content: "小熊胖胖刚搬到森林里，它一个朋友都没有，觉得很孤单。\n\n胖胖决定去找朋友。它先遇到了小猴子，小猴子正在树上荡秋千。\"小猴子，我能和你做朋友吗？\"胖胖问。小猴子说：\"你会荡秋千吗？\"胖胖摇摇头，它太重了，树枝承受不住。\n\n接着胖胖遇到了小鱼，小鱼在河里游泳。\"小鱼，我能和你做朋友吗？\"小鱼说：\"你会游泳吗？\"胖胖又摇摇头，它怕水。\n\n胖胖有点难过，坐在草地上哭了起来。这时候，小蜜蜂飞过来问：\"小熊，你怎么了？\"胖胖说：\"我什么都不会，没有人愿意和我做朋友。\"\n\n小蜜蜂笑着说：\"每个人都有自己的特长呀！你力气大，可以帮大家搬东西呀！\"正好，小兔子的胡萝卜太多搬不动，胖胖过去轻轻松松就帮小兔子把胡萝卜运回了家。\n\n大家看到胖胖这么热心，都愿意和它做朋友了。胖胖终于明白，做真实的自己，用自己的方式帮助别人，就能交到好朋友。",
            summary: "小熊胖胖通过帮助别人找到了朋友，学会了接纳自己和乐于助人。",
            theme: "友谊",
            style: "温馨",
            targetAgeGroup: "4-5岁",
            coverImageURL: nil,
            coverGradient: ["#C8E6C9", "#A5D6A7"],
            coverEmoji: "teddybear.fill",
            audioURL: nil,
            localAudioPath: nil,
            duration: 300,
            wordCount: 400,
            voiceModelId: nil,
            voiceModelName: nil,
            isAIGenerated: true,
            isFavorite: false,
            isDownloaded: false,
            playCount: 3,
            createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            updatedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            tags: ["小熊", "友谊", "自信"],
            characters: ["胖胖", "小猴子", "小鱼", "小蜜蜂", "小兔子"]
        ),
        Story(
            id: "story_005",
            title: "魔法画笔",
            content: "小女孩朵朵有一支神奇的画笔，用它画出来的东西都会变成真的。\n\n朵朵用画笔画了好多好吃的糖果，糖果真的从画纸上飞了下来！她又画了一只小猫，小猫\"喵\"的一声就活了过来。朵朵开心极了。\n\n但是有一天，朵朵不小心画了一场大雨，雨水把整个院子都淹了。她又急又怕，不知道怎么办才好。\n\n这时候，奶奶走过来，温柔地说：\"朵朵，魔法画笔不是用来随心所欲的，而是要用来帮助别人的。\"朵朵听了奶奶的话，想了想。\n\n她画了一个大大的太阳，阳光把雨水晒干了。她画了美丽的花朵，院子变得漂漂亮亮。她还画了好多书本和玩具，送给了孤儿院的小朋友们。\n\n朵朵终于明白了，拥有魔法不是最重要的，重要的是用自己的能力去帮助需要帮助的人。从那以后，朵朵成了一个善良又有爱心的小魔法师。",
            summary: "小女孩朵朵用魔法画笔帮助他人，学会了正确使用自己的能力。",
            theme: "魔法",
            style: "童话",
            targetAgeGroup: "4-5岁",
            coverImageURL: nil,
            coverGradient: ["#F8BBD0", "#F48FB1"],
            coverEmoji: "paintpalette.fill",
            audioURL: "https://example.com/audio/story_005.mp3",
            localAudioPath: nil,
            duration: 340,
            wordCount: 450,
            voiceModelId: "voice_001",
            voiceModelName: "妈妈的声音",
            isAIGenerated: true,
            isFavorite: false,
            isDownloaded: false,
            playCount: 15,
            createdAt: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
            updatedAt: Calendar.current.date(byAdding: .day, value: -4, to: Date()) ?? Date(),
            tags: ["魔法", "善良", "帮助"],
            characters: ["朵朵", "奶奶"]
        ),
        Story(
            id: "story_006",
            title: "海底小纵队的奇妙旅行",
            content: "在蔚蓝的大海深处，有一支勇敢的海底小纵队。队长是聪明的小海豚波波，队员们有力气大的小鲸鱼壮壮、眼睛亮的小章鱼八爪，还有速度快的小剑鱼飞飞。\n\n一天，他们收到了一个求救信号——珊瑚礁里的小丑鱼迷路了！小纵队立刻出发去救援。\n\n他们穿过五彩斑斓的珊瑚丛，游过神秘的海底洞穴，躲过了巨大的水母群。在一片海草丛中，他们终于找到了害怕得发抖的小丑鱼。\n\n\"别怕，我们送你回家！\"波波温柔地说。小纵队围成一个保护圈，把小丑鱼护在中间，安全地送回了它的家。\n\n小丑鱼的爸爸妈妈非常感激，为小纵队准备了美味的海草蛋糕。大家一起在海底开起了派对，所有的海洋生物都来参加了。\n\n波波对队员们说：\"只要我们团结一心，就没有解决不了的困难！\"大家都开心地点头，海底充满了欢声笑语。",
            summary: "海底小纵队团结协作帮助迷路的小丑鱼回家，展现了团队合作的力量。",
            theme: "动物",
            style: "幽默",
            targetAgeGroup: "6-8岁",
            coverImageURL: nil,
            coverGradient: ["#80DEEA", "#4DD0E1"],
            coverEmoji: "fish.fill",
            audioURL: "https://example.com/audio/story_006.mp3",
            localAudioPath: nil,
            duration: 400,
            wordCount: 520,
            voiceModelId: "voice_002",
            voiceModelName: "爸爸的声音",
            isAIGenerated: false,
            isFavorite: true,
            isDownloaded: false,
            playCount: 20,
            createdAt: Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date(),
            updatedAt: Calendar.current.date(byAdding: .day, value: -12, to: Date()) ?? Date(),
            tags: ["海洋", "动物", "团队", "冒险"],
            characters: ["波波", "壮壮", "八爪", "飞飞", "小丑鱼"]
        )
    ]

    static var mockFeatured: [Story] {
        Array(mockStories.prefix(3))
    }

    static var mockRecent: [Story] {
        Array(mockStories.suffix(3))
    }

    static var mockFavorites: [Story] {
        mockStories.filter { $0.isFavorite }
    }
}
