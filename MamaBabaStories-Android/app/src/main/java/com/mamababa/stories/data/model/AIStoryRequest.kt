package com.mamababa.stories.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * AI 故事创作请求
 */
@Serializable
data class AIStoryRequest(
    @SerialName("theme") val theme: String = "",           // 主题关键词
    @SerialName("character") val character: String = "",    // 主角名字
    @SerialName("age_min") val ageMin: Int = 3,
    @SerialName("age_max") val ageMax: Int = 6,
    @SerialName("style") val style: String = "warm",        // warm/humorous/adventure/educational/lullaby
    @SerialName("length") val length: String = "medium",    // short/medium/long
    @SerialName("voice_model_id") val voiceModelId: String = "",
    @SerialName("child_name") val childName: String = "",   // 代入孩子名字
    @SerialName("extra_prompt") val extraPrompt: String = ""
) {
    companion object {
        val STYLES = listOf(
            "warm" to "温馨",
            "humorous" to "幽默",
            "adventure" to "冒险",
            "educational" to "益智",
            "lullaby" to "睡前"
        )
        val LENGTHS = listOf(
            "short" to "短篇（2分钟）",
            "medium" to "中篇（5分钟）",
            "long" to "长篇（10分钟）"
        )
        val THEMES = listOf(
            "森林冒险", "太空旅行", "海底世界", "魔法城堡",
            "动物朋友", "四季变化", "节日故事", "成长勇气",
            "分享友谊", "好习惯"
        )
    }
}

/**
 * AI 创作响应
 */
@Serializable
data class AIStoryResponse(
    @SerialName("story_id") val storyId: String = "",
    @SerialName("title") val title: String = "",
    @SerialName("text_content") val textContent: String = "",
    @SerialName("duration_sec") val durationSec: Int = 0,
    @SerialName("audio_url") val audioUrl: String = "",
    @SerialName("status") val status: String = "completed" // generating/completed/failed
)

/**
 * 通用 API 响应包装
 */
@Serializable
data class ApiResponse<T>(
    @SerialName("code") val code: Int = 0,
    @SerialName("message") val message: String = "",
    @SerialName("data") val data: T? = null
) {
    val isSuccess: Boolean get() = code == 0
}

/**
 * 分页响应
 */
@Serializable
data class PageResponse<T>(
    @SerialName("list") val list: List<T> = emptyList(),
    @SerialName("total") val total: Int = 0,
    @SerialName("page") val page: Int = 1,
    @SerialName("page_size") val pageSize: Int = 20,
    @SerialName("has_more") val hasMore: Boolean = false
)
