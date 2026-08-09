package com.mamababa.stories.data.api

/**
 * API 端点常量
 */
object ApiEndpoints {
    // 认证
    const val SEND_CODE = "/api/v1/auth/send_code"
    const val LOGIN = "/api/v1/auth/login"
    const val REFRESH_TOKEN = "/api/v1/auth/refresh"
    const val USER_PROFILE = "/api/v1/user/profile"
    const val UPDATE_PROFILE = "/api/v1/user/profile"
    const val CHILDREN = "/api/v1/user/children"

    // 故事
    const val STORIES = "/api/v1/stories"
    const val STORY_DETAIL = "/api/v1/stories/{id}"
    const val STORY_RECOMMEND = "/api/v1/stories/recommend"
    const val STORY_RECENT = "/api/v1/stories/recent"
    const val STORY_LIKE = "/api/v1/stories/{id}/like"
    const val STORY_PLAY = "/api/v1/stories/{id}/play"
    const val STORY_CATEGORIES = "/api/v1/stories/categories"
    const val STORY_SEARCH = "/api/v1/stories/search"

    // 声音模型
    const val VOICE_MODELS = "/api/v1/voices"
    const val VOICE_MODEL_DETAIL = "/api/v1/voices/{id}"
    const val VOICE_UPLOAD = "/api/v1/voices/upload"
    const val VOICE_TRAIN = "/api/v1/voices/train"
    const val VOICE_DELETE = "/api/v1/voices/{id}"
    const val VOICE_SAMPLE = "/api/v1/voices/{id}/sample"

    // AI 创作
    const val AI_CREATE = "/api/v1/ai/create"
    const val AI_STATUS = "/api/v1/ai/status/{id}"
    const val AI_HISTORY = "/api/v1/ai/history"

    // TTS 流式合成 (WebSocket)
    const val TTS_STREAM_WS = "/ws/tts"
    const val TTS_SYNTHESIZE = "/api/v1/tts/synthesize"

    // 下载
    const val DOWNLOAD_STORY = "/api/v1/stories/{id}/download"

    // 会员
    const val MEMBERSHIP = "/api/v1/membership"
    const val MEMBERSHIP_PLANS = "/api/v1/membership/plans"
}
