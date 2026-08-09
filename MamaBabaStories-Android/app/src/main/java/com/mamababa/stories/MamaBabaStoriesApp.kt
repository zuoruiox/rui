package com.mamababa.stories

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import com.mamababa.stories.data.api.ApiClient
import com.mamababa.stories.service.audio.AudioPlayerManager
import com.mamababa.stories.util.Constants
import com.mamababa.stories.util.PreferenceHelper

/**
 * Application 入口
 * 负责全局初始化：偏好设置、通知渠道、全局单例
 */
class MamaBabaStoriesApp : Application() {

    lateinit var apiClient: ApiClient
        private set

    lateinit var audioPlayerManager: AudioPlayerManager
        private set

    override fun onCreate() {
        super.onCreate()
        instance = this

        // 初始化偏好设置
        PreferenceHelper.init(this)

        // 初始化 API 客户端
        apiClient = ApiClient.getInstance(this)

        // 初始化音频播放器管理器
        audioPlayerManager = AudioPlayerManager(this)

        // 创建通知渠道
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val playbackChannel = NotificationChannel(
                Constants.NOTIFICATION_CHANNEL_PLAYBACK,
                "播放控制",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "故事播放通知"
                setShowBadge(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(playbackChannel)
        }
    }

    override fun onTerminate() {
        super.onTerminate()
        if (::audioPlayerManager.isInitialized) {
            audioPlayerManager.release()
        }
    }

    companion object {
        @Volatile
        private var instance: MamaBabaStoriesApp? = null

        fun getInstance(): MamaBabaStoriesApp =
            instance ?: throw IllegalStateException("Application not initialized")
    }
}
