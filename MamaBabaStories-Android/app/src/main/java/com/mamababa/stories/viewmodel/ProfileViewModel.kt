package com.mamababa.stories.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mamababa.stories.data.model.User
import com.mamababa.stories.data.model.VoiceModel
import com.mamababa.stories.data.repository.VoiceRepository
import com.mamababa.stories.util.PreferenceHelper
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

data class ProfileUiState(
    val user: User? = null,
    val voices: List<VoiceModel> = emptyList(),
    val isLoading: Boolean = true,
    val autoPlayNext: Boolean = true,
    val playbackSpeed: Float = 1.0f,
    val showSpeedDialog: Boolean = false,
    val showLogoutDialog: Boolean = false
)

class ProfileViewModel(
    private val voiceRepository: VoiceRepository = VoiceRepository()
) : ViewModel() {

    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            PreferenceHelper.userFlow.collect { user ->
                _uiState.update { it.copy(user = user) }
            }
        }
        viewModelScope.launch {
            PreferenceHelper.playbackSpeedFlow.collect { speed ->
                _uiState.update { it.copy(playbackSpeed = speed) }
            }
        }
        loadVoices()
        _uiState.update {
            it.copy(autoPlayNext = PreferenceHelper.isAutoPlayNext())
        }
    }

    private fun loadVoices() {
        viewModelScope.launch {
            voiceRepository.getVoiceModels().collect { result ->
                result.onSuccess { voices ->
                    _uiState.update { it.copy(voices = voices, isLoading = false) }
                }
            }
        }
    }

    fun setAutoPlayNext(auto: Boolean) {
        PreferenceHelper.setAutoPlayNext(auto)
        _uiState.update { it.copy(autoPlayNext = auto) }
    }

    fun setPlaybackSpeed(speed: Float) {
        PreferenceHelper.savePlaybackSpeed(speed)
        com.mamababa.stories.MamaBabaStoriesApp.getInstance()
            .audioPlayerManager.setPlaybackSpeed(speed)
        _uiState.update { it.copy(playbackSpeed = speed, showSpeedDialog = false) }
    }

    fun showSpeedDialog(show: Boolean) {
        _uiState.update { it.copy(showSpeedDialog = show) }
    }

    fun showLogoutDialog(show: Boolean) {
        _uiState.update { it.copy(showLogoutDialog = show) }
    }

    fun logout() {
        PreferenceHelper.clearToken()
        PreferenceHelper.clearUser()
        _uiState.update { it.copy(showLogoutDialog = false, user = null) }
    }
}
