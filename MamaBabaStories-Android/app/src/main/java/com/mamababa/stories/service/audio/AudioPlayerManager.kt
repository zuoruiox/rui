package com.mamababa.stories.service.audio

import android.content.Context
import android.net.Uri
import androidx.media3.common.*
import androidx.media3.common.AudioAttributes as Media3AudioAttributes
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import androidx.media3.session.MediaSession
import com.mamababa.stories.MamaBabaStoriesApp
import com.mamababa.stories.data.model.Story
import com.mamababa.stories.util.Constants
import com.mamababa.stories.util.PreferenceHelper
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import okhttp3.OkHttpClient

/**
 * 播放状态
 */
enum class PlaybackState {
    IDLE, BUFFERING, PLAYING, PAUSED, ENDED, ERROR
}

/**
 * 播放状态数据
 */
data class PlayerState(
    val currentStory: Story? = null,
    val playbackState: PlaybackState = PlaybackState.IDLE,
    val currentPositionMs: Long = 0L,
    val durationMs: Long = 0L,
    val bufferedPositionMs: Long = 0L,
    val speed: Float = 1.0f,
    val isShuffle: Boolean = false,
    val repeatMode: Int = 0, // 0=不循环, 1=单曲循环
    val sleepTimerEndAt: Long = Constants.SLEEP_TIMER_OFF,
    val isSleepTimerActive: Boolean = false,
    val playlist: List<Story> = emptyList(),
    val currentIndex: Int = -1,
    val error: String? = null
) {
    val progress: Float
        get() = if (durationMs > 0) currentPositionMs.toFloat() / durationMs else 0f

    val isPlaying: Boolean get() = playbackState == PlaybackState.PLAYING
}

/**
 * 音频播放器管理器
 * 基于 Media3 ExoPlayer，支持：
 * - 本地/网络音频播放
 * - 后台播放（配合 MediaSession + 前台服务）
 * - 播放速度控制
 * - 睡眠定时（带淡出）
 * - 音频焦点管理
 * - 播放列表
 */
class AudioPlayerManager(private val context: Context) {

    private val app = MamaBabaStoriesApp.getInstance()
    internal val exoPlayer: ExoPlayer
    private var mediaSession: MediaSession? = null

    private val _state = MutableStateFlow(PlayerState())
    val state: StateFlow<PlayerState> = _state.asStateFlow()

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var progressJob: Job? = null
    private var sleepTimerJob: Job? = null
    private var fadeOutJob: Job? = null

    private var playlist = mutableListOf<Story>()
    private var currentIndex = -1

    // 音频焦点管理
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
    private var audioFocusRequest: android.media.AudioFocusRequest? = null
    private var hasFocus = false
    private val focusChangeListener = android.media.AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            android.media.AudioManager.AUDIOFOCUS_GAIN -> {
                exoPlayer.volume = 1f
                if (_state.value.playbackState == PlaybackState.PAUSED) {
                    // 因焦点丢失暂停的，恢复
                    play()
                }
            }
            android.media.AudioManager.AUDIOFOCUS_LOSS -> {
                pause()
                abandonAudioFocus()
            }
            android.media.AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                if (_state.value.isPlaying) pause()
            }
            android.media.AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                exoPlayer.volume = 0.3f
            }
        }
    }

    init {
        val okHttpClient = app.apiClient.getOkHttpClient()
        val dataSourceFactory = DefaultDataSource.Factory(
            context,
            OkHttpDataSource.Factory(okHttpClient)
        )
        val mediaSourceFactory = DefaultMediaSourceFactory(context)
            .setDataSourceFactory(dataSourceFactory)

        exoPlayer = ExoPlayer.Builder(context)
            .setMediaSourceFactory(mediaSourceFactory)
            .setAudioAttributes(
                Media3AudioAttributes.Builder()
                    .setUsage(C.USAGE_MEDIA)
                    .setContentType(C.AUDIO_CONTENT_TYPE_SPEECH)
                    .build(),
                true
            )
            .setHandleAudioBecomingNoisy(true)
            .build()

        exoPlayer.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                val newState = when (playbackState) {
                    Player.STATE_IDLE -> PlaybackState.IDLE
                    Player.STATE_BUFFERING -> PlaybackState.BUFFERING
                    Player.STATE_READY -> {
                        if (exoPlayer.playWhenReady) PlaybackState.PLAYING else PlaybackState.PAUSED
                    }
                    Player.STATE_ENDED -> PlaybackState.ENDED
                    else -> PlaybackState.IDLE
                }
                updateState { copy(playbackState = newState) }

                if (playbackState == Player.STATE_ENDED) {
                    onPlaybackEnded()
                }
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                updateState {
                    copy(playbackState = if (isPlaying) PlaybackState.PLAYING else PlaybackState.PAUSED)
                }
                if (isPlaying) startProgressTracking() else stopProgressTracking()
            }

            override fun onPlayerError(error: PlaybackException) {
                updateState {
                    copy(playbackState = PlaybackState.ERROR, error = error.message)
                }
            }

            override fun onPositionDiscontinuity(
                oldPosition: Player.PositionInfo,
                newPosition: Player.PositionInfo,
                reason: Int
            ) {
                if (reason == Player.DISCONTINUITY_REASON_AUTO_TRANSITION) {
                    // 自动切歌
                    currentIndex = exoPlayer.currentMediaItemIndex
                    updateCurrentStory()
                }
            }
        })

        // 初始化 MediaSession
        mediaSession = MediaSession.Builder(context, exoPlayer)
            .setCallback(object : MediaSession.Callback {
                override fun onPlay() { play() }
                override fun onPause() { pause() }
                override fun onSkipToNext() { playNext() }
                override fun onSkipToPrevious() { playPrevious() }
                override fun onStop() { pause() }
            })
            .build()

        // 恢复上次速度
        exoPlayer.setPlaybackSpeed(PreferenceHelper.getPlaybackSpeed())
    }

    fun getMediaSession(): MediaSession? = mediaSession

    // ========== 播放控制 ==========

    /**
     * 播放单个故事
     */
    fun playStory(story: Story, storyList: List<Story>? = null) {
        val list = storyList ?: listOf(story)
        playlist = list.toMutableList()
        currentIndex = list.indexOfFirst { it.id == story.id }.coerceAtLeast(0)
        buildPlaylistAndPlay(currentIndex)
    }

    /**
     * 播放播放列表中指定位置
     */
    fun playAt(index: Int) {
        if (index in playlist.indices) {
            currentIndex = index
            buildPlaylistAndPlay(index)
        }
    }

    private fun buildPlaylistAndPlay(startIndex: Int) {
        exoPlayer.stop()
        exoPlayer.clearMediaItems()

        playlist.forEach { story ->
            val uri = when {
                story.localPath.isNotEmpty() -> Uri.parse("file://${story.localPath}")
                story.audioUrl.isNotEmpty() -> Uri.parse(story.audioUrl)
                else -> Uri.parse("asset:///dummy.mp3") // 占位
            }
            val mediaItem = MediaItem.Builder()
                .setUri(uri)
                .setMediaId(story.id)
                .setMediaMetadata(
                    MediaMetadata.Builder()
                        .setTitle(story.title)
                        .setArtist(story.voiceName)
                        .build()
                )
                .build()
            exoPlayer.addMediaItem(mediaItem)
        }

        exoPlayer.prepare()
        exoPlayer.seekTo(startIndex, 0)
        exoPlayer.playWhenReady = true
        requestAudioFocus()
        exoPlayer.play()

        updateCurrentStory()
        updateState {
            copy(
                playlist = playlist.toList(),
                currentIndex = currentIndex,
                speed = exoPlayer.playbackParameters.speed
            )
        }
    }

    fun play() {
        if (!hasFocus) requestAudioFocus()
        exoPlayer.play()
    }

    fun pause() {
        exoPlayer.pause()
    }

    fun togglePlayPause() {
        if (exoPlayer.isPlaying) pause() else play()
    }

    fun playNext() {
        if (currentIndex < playlist.size - 1) {
            currentIndex++
            exoPlayer.seekToNextMediaItem()
            updateCurrentStory()
        } else if (_state.value.repeatMode == 1) {
            exoPlayer.seekTo(0, 0)
            exoPlayer.play()
        }
    }

    fun playPrevious() {
        if (exoPlayer.currentPosition > 3000) {
            exoPlayer.seekTo(0)
        } else if (currentIndex > 0) {
            currentIndex--
            exoPlayer.seekToPreviousMediaItem()
            updateCurrentStory()
        } else {
            exoPlayer.seekTo(0)
        }
    }

    fun seekTo(positionMs: Long) {
        exoPlayer.seekTo(positionMs)
    }

    fun seekTo(progress: Float) {
        val duration = exoPlayer.duration
        if (duration > 0) {
            exoPlayer.seekTo((duration * progress).toLong())
        }
    }

    fun setPlaybackSpeed(speed: Float) {
        exoPlayer.setPlaybackSpeed(speed)
        PreferenceHelper.savePlaybackSpeed(speed)
        updateState { copy(speed = speed) }
    }

    fun setRepeatMode(mode: Int) {
        exoPlayer.repeatMode = if (mode == 1) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF
        updateState { copy(repeatMode = mode) }
    }

    fun toggleRepeatMode() {
        val next = (_state.value.repeatMode + 1) % 2
        setRepeatMode(next)
    }

    // ========== 睡眠定时 ==========

    /**
     * 设置睡眠定时器
     * @param minutes 分钟数，Constants.SLEEP_TIMER_OFF 表示关闭
     */
    fun setSleepTimer(minutes: Long) {
        sleepTimerJob?.cancel()
        fadeOutJob?.cancel()

        if (minutes == Constants.SLEEP_TIMER_OFF || minutes <= 0) {
            updateState { copy(sleepTimerEndAt = Constants.SLEEP_TIMER_OFF, isSleepTimerActive = false) }
            exoPlayer.volume = 1f
            return
        }

        val endAt = System.currentTimeMillis() + minutes * 60 * 1000
        updateState { copy(sleepTimerEndAt = endAt, isSleepTimerActive = true) }

        sleepTimerJob = scope.launch {
            val fadeStartAt = endAt - Constants.FADE_OUT_DURATION_MS
            delay(fadeStartAt - System.currentTimeMillis())
            // 开始淡出
            val fadeSteps = 50
            val stepDelay = Constants.FADE_OUT_DURATION_MS / fadeSteps
            for (i in fadeSteps downTo 0) {
                exoPlayer.volume = i.toFloat() / fadeSteps
                delay(stepDelay)
            }
            pause()
            exoPlayer.volume = 1f
            updateState { copy(sleepTimerEndAt = Constants.SLEEP_TIMER_OFF, isSleepTimerActive = false) }
        }
    }

    fun cancelSleepTimer() {
        setSleepTimer(Constants.SLEEP_TIMER_OFF)
    }

    // ========== 内部方法 ==========

    private fun onPlaybackEnded() {
        if (currentIndex >= playlist.size - 1) {
            if (_state.value.repeatMode == 1) {
                exoPlayer.seekTo(0, 0)
                exoPlayer.play()
            } else if (PreferenceHelper.isAutoPlayNext()) {
                // 停止
                stopProgressTracking()
            }
        }
    }

    private fun updateCurrentStory() {
        val story = playlist.getOrNull(currentIndex)
        updateState { copy(currentStory = story, currentIndex = currentIndex) }
    }

    private fun startProgressTracking() {
        progressJob?.cancel()
        progressJob = scope.launch {
            while (isActive) {
                updateState {
                    copy(
                        currentPositionMs = exoPlayer.currentPosition,
                        durationMs = exoPlayer.duration.coerceAtLeast(0L),
                        bufferedPositionMs = exoPlayer.bufferedPosition
                    )
                }
                delay(500)
            }
        }
    }

    private fun stopProgressTracking() {
        progressJob?.cancel()
        progressJob = null
    }

    private fun requestAudioFocus(): Boolean {
        val result = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val request = android.media.AudioFocusRequest.Builder(android.media.AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_MEDIA)
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                .setOnAudioFocusChangeListener(focusChangeListener)
                .build()
            audioFocusRequest = request
            audioManager.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                focusChangeListener,
                android.media.AudioManager.STREAM_MUSIC,
                android.media.AudioManager.AUDIOFOCUS_GAIN
            )
        }
        hasFocus = result == android.media.AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        return hasFocus
    }

    private fun abandonAudioFocus() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            audioFocusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(focusChangeListener)
        }
        hasFocus = false
    }

    private fun updateState(transform: PlayerState.() -> PlayerState) {
        _state.value = _state.value.transform()
    }

    fun release() {
        stopProgressTracking()
        sleepTimerJob?.cancel()
        fadeOutJob?.cancel()
        scope.cancel()
        abandonAudioFocus()
        mediaSession?.release()
        mediaSession = null
        exoPlayer.release()
    }
}
