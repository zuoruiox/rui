package com.mamababa.stories.util

/**
 * 全局常量
 */
object Constants {

    // 音频参数
    const val SAMPLE_RATE = 24000          // 采样率 24kHz
    const val BITS_PER_SAMPLE = 16         // 位深 16bit
    const val CHANNEL_COUNT = 1            // 单声道
    const val RECORDING_MIN_DURATION_MS = 60_000L   // 最少录制 1 分钟
    const val RECORDING_MAX_DURATION_MS = 300_000L  // 最多录制 5 分钟
    const val RECORDING_TARGET_DURATION_MS = 180_000L // 目标 3 分钟

    // VAD 参数
    const val VAD_ENERGY_THRESHOLD = 500   // 语音能量阈值
    const val VAD_SILENCE_TIMEOUT_MS = 2000L // 静音超时
    const val CLIPPING_THRESHOLD = 32000   // 削波阈值（接近 Short.MAX_VALUE）
    const val SILENCE_THRESHOLD = 200      // 静音阈值

    // 播放
    const val PLAYBACK_SPEED_DEFAULT = 1.0f
    const val SLEEP_TIMER_OFF = -1L
    const val FADE_OUT_DURATION_MS = 5000L

    // 分页
    const val PAGE_SIZE = 20
    const val PREFETCH_DISTANCE = 5

    // 通知
    const val NOTIFICATION_CHANNEL_PLAYBACK = "playback_channel"
    const val NOTIFICATION_ID_PLAYBACK = 1001

    // DataStore / SharedPreferences 键
    const val PREF_NAME = "mamababa_stories_prefs"
    const val KEY_TOKEN = "auth_token"
    const val KEY_REFRESH_TOKEN = "refresh_token"
    const val KEY_TOKEN_EXPIRES_AT = "token_expires_at"
    const val KEY_USER_JSON = "user_json"
    const val KEY_LAST_VOICE_ID = "last_voice_id"
    const val KEY_PLAYBACK_SPEED = "playback_speed"
    const val KEY_SLEEP_TIMER = "sleep_timer"
    const val KEY_AUTO_PLAY_NEXT = "auto_play_next"

    // 下载
    const val DOWNLOAD_DIR = "stories"
    const val VOICE_DIR = "voices"
    const val RECORD_DIR = "recordings"

    // WebSocket
    const val WS_NORMAL_CLOSURE = 1000
}
