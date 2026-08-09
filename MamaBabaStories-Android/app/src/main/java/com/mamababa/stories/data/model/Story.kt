package com.mamababa.stories.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * 故事分类
 */
enum class StoryCategory(val value: String, val displayName: String) {
    FAIRY("fairy", "童话"),
    FABLE("fable", "寓言"),
    SCIENCE("science", "科普"),
    HISTORY("history", "历史"),
    LULLABY("lullaby", "睡前"),
    CUSTOM("custom", "原创");

    companion object {
        fun fromValue(v: String?): StoryCategory =
            entries.firstOrNull { it.value == v } ?: FAIRY
    }
}

/**
 * 故事来源
 */
enum class StorySource {
    OFFICIAL,   // 官方
    AI_CREATED, // AI 创作
    RECORDED    // 用户录制
}

/**
 * 故事
 */
@Serializable
data class Story(
    @SerialName("id") val id: String = "",
    @SerialName("title") val title: String = "",
    @SerialName("author") val author: String = "",
    @SerialName("cover_url") val coverUrl: String = "",
    @SerialName("description") val description: String = "",
    @SerialName("category") val categoryRaw: String = "fairy",
    @SerialName("tags") val tags: List<String> = emptyList(),
    @SerialName("age_min") val ageMin: Int = 3,
    @SerialName("age_max") val ageMax: Int = 6,
    @SerialName("duration_sec") val durationSec: Int = 300,
    @SerialName("audio_url") val audioUrl: String = "",
    @SerialName("text_content") val textContent: String = "",
    @SerialName("voice_model_id") val voiceModelId: String = "",
    @SerialName("voice_name") val voiceName: String = "",
    @SerialName("play_count") val playCount: Long = 0,
    @SerialName("like_count") val likeCount: Long = 0,
    @SerialName("is_liked") val isLiked: Boolean = false,
    @SerialName("is_downloaded") val isDownloaded: Boolean = false,
    @SerialName("local_path") val localPath: String = "",
    @SerialName("source") val sourceRaw: String = "official",
    @SerialName("created_at") val createdAt: Long = System.currentTimeMillis()
) {
    val category: StoryCategory get() = StoryCategory.fromValue(categoryRaw)

    val source: StorySource
        get() = when (sourceRaw) {
            "ai" -> StorySource.AI_CREATED
            "recorded" -> StorySource.RECORDED
            else -> StorySource.OFFICIAL
        }

    val ageRange: String get() = "${ageMin}-${ageMax}岁"

    val durationText: String
        get() {
            val min = durationSec / 60
            val sec = durationSec % 60
            return if (min > 0) "${min}分${sec}秒" else "${sec}秒"
        }

    val durationMinutes: String get() = "${(durationSec + 30) / 60}分钟"

    companion object {
        private val SAMPLE_TEXT = """
            从前，在一片美丽的大森林里，住着一只可爱的小兔子，名字叫豆豆。
            豆豆有一双长长的耳朵，一双红红的眼睛，还有一身雪白的毛。
            有一天，豆豆在森林里散步，遇到了一只小松鼠。
            小松鼠说："豆豆，你好呀！我们一起去采蘑菇吧！"
            豆豆高兴地说："好呀好呀！"
            他们一起在森林里采了好多好多蘑菇，还认识了许多新朋友。
            太阳快落山的时候，豆豆带着满满的一篮子蘑菇回家了。
            妈妈看到了，开心地说："豆豆真是个能干的好孩子！"
            晚上，豆豆躺在温暖的小床上，做了一个甜甜的梦。
        """.trimIndent()

        val PREVIEW_1 = Story(
            id = "story_1",
            title = "小兔子豆豆的冒险",
            author = "爸爸妈妈讲故事",
            coverUrl = "",
            description = "一只勇敢的小兔子在森林里的奇妙冒险",
            categoryRaw = "fairy",
            tags = listOf("勇敢", "友谊", "森林"),
            ageMin = 3,
            ageMax = 6,
            durationSec = 420,
            audioUrl = "",
            textContent = SAMPLE_TEXT,
            voiceModelId = "voice_mom",
            voiceName = "温柔妈妈",
            playCount = 12580,
            likeCount = 892,
            isLiked = true,
            sourceRaw = "official"
        )

        val PREVIEW_2 = Story(
            id = "story_2",
            title = "龟兔赛跑新传",
            author = "爸爸妈妈讲故事",
            coverUrl = "",
            description = "经典寓言的全新演绎",
            categoryRaw = "fable",
            tags = listOf("坚持", "谦虚"),
            ageMin = 4,
            ageMax = 8,
            durationSec = 360,
            audioUrl = "",
            textContent = SAMPLE_TEXT,
            voiceModelId = "voice_dad",
            voiceName = "磁性爸爸",
            playCount = 8920,
            likeCount = 567,
            sourceRaw = "official"
        )

        val PREVIEW_3 = Story(
            id = "story_3",
            title = "小星星的秘密",
            author = "爸爸妈妈讲故事",
            coverUrl = "",
            description = "一个关于星星的温柔睡前故事",
            categoryRaw = "lullaby",
            tags = listOf("睡前", "温馨"),
            ageMin = 2,
            ageMax = 5,
            durationSec = 280,
            audioUrl = "",
            textContent = SAMPLE_TEXT,
            voiceModelId = "voice_mom",
            voiceName = "温柔妈妈",
            playCount = 23450,
            likeCount = 1890,
            sourceRaw = "official"
        )

        val PREVIEW_4 = Story(
            id = "story_4",
            title = "为什么天空是蓝色的",
            author = "爸爸妈妈讲故事",
            coverUrl = "",
            description = "给小朋友的科学启蒙故事",
            categoryRaw = "science",
            tags = listOf("科学", "自然"),
            ageMin = 5,
            ageMax = 9,
            durationSec = 500,
            audioUrl = "",
            textContent = SAMPLE_TEXT,
            voiceModelId = "voice_dad",
            voiceName = "磁性爸爸",
            playCount = 5670,
            likeCount = 321,
            sourceRaw = "official"
        )

        val PREVIEW_AI = Story(
            id = "story_ai_1",
            title = "小熊贝贝的月亮船",
            author = "AI 创作",
            coverUrl = "",
            description = "为宝贝定制的专属故事",
            categoryRaw = "fairy",
            tags = listOf("原创", "温馨"),
            ageMin = 3,
            ageMax = 6,
            durationSec = 380,
            audioUrl = "",
            textContent = SAMPLE_TEXT,
            voiceModelId = "voice_mom",
            voiceName = "温柔妈妈",
            playCount = 12,
            likeCount = 3,
            sourceRaw = "ai"
        )

        val MOCK_LIST = listOf(PREVIEW_1, PREVIEW_2, PREVIEW_3, PREVIEW_4, PREVIEW_AI)
    }
}
