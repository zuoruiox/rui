package com.mamababa.stories.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mamababa.stories.data.model.Story
import com.mamababa.stories.data.model.TTSConfig
import com.mamababa.stories.service.audio.PlaybackState
import com.mamababa.stories.service.audio.PlayerState
import com.mamababa.stories.util.Constants
import com.mamababa.stories.util.PreferenceHelper
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

data class PlayerUiState(
    val story: Story? = null,
    val isPlaying: Boolean = false,
    val playbackState: PlaybackState = PlaybackState.IDLE,
    val currentPositionMs: Long = 0L,
    val durationMs: Long = 0L,
    val bufferedPositionMs: Long = 0L,
    val speed: Float = 1.0f,
    val isLiked: Boolean = false,
    val repeatMode: Int = 0,
    val sleepTimerEndAt: Long = Constants.SLEEP_TIMER_OFF,
    val isSleepTimerActive: Boolean = false,
    val showSpeedMenu: Boolean = false,
    val showTimerMenu: Boolean = false,
    val sleepTimerRemainingMin: Long = 0L,
    val playlist: List<Story> = emptyList()
) {
    val progress: Float
        get() = if (durationMs > 0) currentPositionMs.toFloat() / durationMs else 0f
}

class PlayerViewModel : ViewModel() {

    private val playerManager = com.mamababa.stories.MamaBabaStoriesApp.getInstance().audioPlayerManager

    private val _uiState = MutableStateFlow(PlayerUiState())
    val uiState: StateFlow<PlayerUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            playerManager.state.collect { state ->
                _uiState.update {
                    it.copy(
                        story = state.currentStory,
                        isPlaying = state.isPlaying,
                        playbackState = state.playbackState,
                        currentPositionMs = state.currentPositionMs,
                        durationMs = state.durationMs,
                        bufferedPositionMs = state.bufferedPositionMs,
                        speed = state.speed,
                        repeatMode = state.repeatMode,
                        sleepTimerEndAt = state.sleepTimerEndAt,
                        isSleepTimerActive = state.isSleepTimerActive,
                        playlist = state.playlist,
                        isLiked = state.currentStory?.isLiked ?: false
                    )
                }
            }
        }

        // 定时更新剩余时间
        viewModelScope.launch {
            while (true) {
                val state = _uiState.value
                if (state.isSleepTimerActive && state.sleepTimerEndAt > 0) {
                    val remaining = (state.sleepTimerEndAt - System.currentTimeMillis()) / 60000
                    _uiState.update { it.copy(sleepTimerRemainingMin = remaining.coerceAtLeast(0)) }
                }
                kotlinx.coroutines.delay(1000)
            }
        }
    }

    fun play() = playerManager.play()
    fun pause() = playerManager.pause()
    fun togglePlayPause() = playerManager.togglePlayPause()
    fun playNext() = playerManager.playNext()
    fun playPrevious() = playerManager.playPrevious()
    fun seekTo(positionMs: Long) = playerManager.seekTo(positionMs)
    fun seekTo(progress: Float) = playerManager.seekTo(progress)
    fun setSpeed(speed: Float) = playerManager.setPlaybackSpeed(speed)
    fun toggleRepeat() = playerManager.toggleRepeatMode()

    fun setSleepTimer(minutes: Long) {
        playerManager.setSleepTimer(minutes)
        _uiState.update { it.copy(showTimerMenu = false) }
    }

    fun cancelSleepTimer() {
        playerManager.cancelSleepTimer()
    }

    fun toggleSpeedMenu() {
        _uiState.update { it.copy(showSpeedMenu = !it.showSpeedMenu, showTimerMenu = false) }
    }

    fun toggleTimerMenu() {
        _uiState.update { it.copy(showTimerMenu = !it.showTimerMenu, showSpeedMenu = false) }
    }

    fun dismissMenus() {
        _uiState.update { it.copy(showSpeedMenu = false, showTimerMenu = false) }
    }

    fun playStory(story: Story, playlist: List<Story>? = null) {
        playerManager.playStory(story, playlist)
    }
}
