package com.mamababa.stories.service.notification

import android.app.Notification
import android.app.PendingIntent
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import android.os.Build
import androidx.annotation.OptIn
import androidx.core.app.NotificationCompat
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import androidx.media3.session.MediaStyleNotificationHelper
import coil.ImageLoader
import coil.request.ImageRequest
import com.mamababa.stories.MainActivity
import com.mamababa.stories.MamaBabaStoriesApp
import com.mamababa.stories.R
import com.mamababa.stories.util.Constants
import kotlinx.coroutines.*

/**
 * 音频前台服务
 * 配合 Media3 MediaSession 提供后台播放、通知栏和锁屏控制
 */
@OptIn(UnstableApi::class)
class AudioNotificationService : MediaSessionService() {

    private var mediaSession: MediaSession? = null
    private val serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    override fun onCreate() {
        super.onCreate()
        val player = MamaBabaStoriesApp.getInstance().audioPlayerManager.exoPlayer

        mediaSession = MediaSession.Builder(this, player)
            .setCallback(object : MediaSession.Callback {
                override fun onPlay(player: Player) {
                    player.play()
                }
                override fun onPause(player: Player) {
                    player.pause()
                }
                override fun onSkipToNext(player: Player) {
                    MamaBabaStoriesApp.getInstance().audioPlayerManager.playNext()
                }
                override fun onSkipToPrevious(player: Player) {
                    MamaBabaStoriesApp.getInstance().audioPlayerManager.playPrevious()
                }
            })
            .build()
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = mediaSession

    override fun onDestroy() {
        mediaSession?.run {
            player.release()
            release()
            mediaSession = null
        }
        serviceScope.cancel()
        super.onDestroy()
    }

    override fun onUpdateNotification(session: MediaSession, startInForegroundRequired: Boolean) {
        val notification = createNotification(session)
        if (startInForegroundRequired) {
            startForeground(Constants.NOTIFICATION_ID_PLAYBACK, notification)
        } else {
            stopForeground(STOP_FOREGROUND_DETACH)
        }
    }

    private fun createNotification(session: MediaSession): Notification {
        val player = session.player
        val mediaMetadata = player.mediaMetadata

        val builder = NotificationCompat.Builder(this, Constants.NOTIFICATION_CHANNEL_PLAYBACK)
            .setContentTitle(mediaMetadata.title?.toString() ?: "爸爸妈妈讲故事")
            .setContentText(mediaMetadata.artist?.toString() ?: "")
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(createContentIntent())
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(player.isPlaying)
            .setStyle(
                MediaStyleNotificationHelper.MediaStyle(session)
                    .setShowActionsInCompactView(0, 1, 2)
            )

        // 添加操作按钮
        builder.addAction(
            R.drawable.ic_skip_previous, "上一个",
            session.sessionActivity
        )

        val playPauseIcon = if (player.isPlaying) R.drawable.ic_pause else R.drawable.ic_play
        builder.addAction(playPauseIcon, if (player.isPlaying) "暂停" else "播放", session.sessionActivity)
        builder.addAction(R.drawable.ic_skip_next, "下一个", session.sessionActivity)

        return builder.build()
    }

    private fun createContentIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
            putExtra("open_player", true)
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getActivity(this, 0, intent, flags)
    }
}
