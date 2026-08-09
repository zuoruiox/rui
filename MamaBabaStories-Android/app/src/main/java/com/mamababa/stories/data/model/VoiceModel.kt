package com.mamababa.stories.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * 声音模型状态
 */
enum class VoiceModelStatus(val value: String) {
    RECORDING("recording"),     // 录制中
    UPLOADING("uploading"),     // 上传中
    TRAINING("training"),       // 训练中
    READY("ready"),             // 就绪可用
    FAILED("failed");           // 失败

    companion object {
        fun fromValue(v: String?): VoiceModelStatus =
            entries.firstOrNull { it.value == v } ?: FAILED
    }
}

/**
 * 声音模型（克隆后的声音）
 */
@Serializable
data class VoiceModel(
    @SerialName("id") val id: String = "",
    @SerialName("name") val name: String = "我的声音",
    @SerialName("owner_type") val ownerType: String = "mom", // mom/dad/grandma/grandpa/custom
    @SerialName("owner_name") val ownerName: String = "妈妈",
    @SerialName("cover_url") val coverUrl: String = "",
    @SerialName("status") val statusRaw: String = "ready",
    @SerialName("progress") val progress: Int = 100, // 训练进度 0-100
    @SerialName("sample_url") val sampleUrl: String = "",
    @SerialName("duration_sec") val durationSec: Int = 180,
    @SerialName("created_at") val createdAt: Long = System.currentTimeMillis(),
    @SerialName("is_default") val isDefault: Boolean = false
) {
    val status: VoiceModelStatus get() = VoiceModelStatus.fromValue(statusRaw)

    val ownerLabel: String
        get() = when (ownerType) {
            "mom" -> "妈妈"
            "dad" -> "爸爸"
            "grandma" -> "奶奶"
            "grandpa" -> "爷爷"
            else -> ownerName
        }

    companion object {
        val PREVIEW_MOM = VoiceModel(
            id = "voice_mom",
            name = "温柔妈妈",
            ownerType = "mom",
            ownerName = "妈妈",
            statusRaw = "ready",
            progress = 100,
            durationSec = 180,
            isDefault = true
        )
        val PREVIEW_DAD = VoiceModel(
            id = "voice_dad",
            name = "磁性爸爸",
            ownerType = "dad",
            ownerName = "爸爸",
            statusRaw = "ready",
            progress = 100,
            durationSec = 200
        )
        val PREVIEW_TRAINING = VoiceModel(
            id = "voice_training",
            name = "训练中",
            ownerType = "custom",
            ownerName = "外婆",
            statusRaw = "training",
            progress = 45
        )
    }
}
