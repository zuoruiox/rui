package com.mamababa.stories.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * TTS（语音合成）配置
 */
@Serializable
data class TTSConfig(
    @SerialName("voice_model_id") val voiceModelId: String = "",
    @SerialName("speed") val speed: Float = 1.0f,      // 0.5 - 2.0
    @SerialName("pitch") val pitch: Float = 1.0f,      // 0.5 - 2.0
    @SerialName("volume") val volume: Float = 1.0f,    // 0.0 - 1.5
    @SerialName("emotion") val emotion: String = "warm", // warm/happy/calm/sad
    @SerialName("format") val format: String = "mp3",
    @SerialName("sample_rate") val sampleRate: Int = 24000,
    @SerialName("streaming") val streaming: Boolean = true
) {
    companion object {
        val DEFAULT = TTSConfig()
        val SPEED_OPTIONS = listOf(0.75f, 1.0f, 1.25f, 1.5f)
        val EMOTIONS = listOf("warm" to "温柔", "happy" to "开心", "calm" to "平静", "sad" to "伤感")
    }
}

/**
 * TTS 合成请求
 */
@Serializable
data class TTSRequest(
    @SerialName("text") val text: String,
    @SerialName("config") val config: TTSConfig = TTSConfig.DEFAULT,
    @SerialName("story_id") val storyId: String = ""
)

/**
 * 录音上传响应
 */
@Serializable
data class UploadResponse(
    @SerialName("file_id") val fileId: String = "",
    @SerialName("url") val url: String = "",
    @SerialName("duration_sec") val durationSec: Int = 0,
    @SerialName("quality_score") val qualityScore: Int = 0
)

/**
 * 声音模型训练请求
 */
@Serializable
data class VoiceTrainRequest(
    @SerialName("name") val name: String,
    @SerialName("owner_type") val ownerType: String = "custom",
    @SerialName("audio_file_ids") val audioFileIds: List<String> = emptyList()
)

/**
 * 登录请求/响应
 */
@Serializable
data class LoginRequest(
    @SerialName("phone") val phone: String,
    @SerialName("code") val code: String
)

@Serializable
data class LoginResponse(
    @SerialName("token") val token: String = "",
    @SerialName("refresh_token") val refreshToken: String = "",
    @SerialName("expires_at") val expiresAt: Long = 0,
    @SerialName("user") val user: User = User()
)
