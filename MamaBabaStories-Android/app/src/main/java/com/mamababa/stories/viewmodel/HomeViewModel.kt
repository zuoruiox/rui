package com.mamababa.stories.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mamababa.stories.data.model.Story
import com.mamababa.stories.data.model.User
import com.mamababa.stories.data.model.VoiceModel
import com.mamababa.stories.data.repository.StoryRepository
import com.mamababa.stories.data.repository.VoiceRepository
import com.mamababa.stories.util.PreferenceHelper
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

data class HomeUiState(
    val user: User? = null,
    val recommendStories: List<Story> = emptyList(),
    val recentStories: List<Story> = emptyList(),
    val voiceModels: List<VoiceModel> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null,
    val greeting: String = "晚上好"
)

class HomeViewModel(
    private val storyRepository: StoryRepository = StoryRepository(),
    private val voiceRepository: VoiceRepository = VoiceRepository()
) : ViewModel() {

    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    init {
        loadData()
        // 监听用户信息
        viewModelScope.launch {
            PreferenceHelper.userFlow.collect { user ->
                _uiState.update { it.copy(user = user) }
            }
        }
    }

    fun loadData() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            // 并行加载
            launch { loadRecommend() }
            launch { loadRecent() }
            launch { loadVoices() }

            _uiState.update { it.copy(isLoading = false) }
        }
    }

    private suspend fun loadRecommend() {
        storyRepository.getRecommendStories().collect { result ->
            result.onSuccess { stories ->
                _uiState.update { it.copy(recommendStories = stories) }
            }.onFailure { e ->
                _uiState.update { it.copy(error = e.message) }
            }
        }
    }

    private suspend fun loadRecent() {
        storyRepository.getRecentStories().collect { result ->
            result.onSuccess { stories ->
                _uiState.update { it.copy(recentStories = stories) }
            }
        }
    }

    private suspend fun loadVoices() {
        voiceRepository.getVoiceModels().collect { result ->
            result.onSuccess { voices ->
                _uiState.update { it.copy(voiceModels = voices) }
            }
        }
    }

    fun playStory(story: Story) {
        val stories = _uiState.value.recommendStories + _uiState.value.recentStories
        com.mamababa.stories.MamaBabaStoriesApp.getInstance()
            .audioPlayerManager.playStory(story, stories.distinctBy { it.id })
    }
}
