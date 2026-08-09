package com.mamababa.stories.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mamababa.stories.data.model.AIStoryRequest
import com.mamababa.stories.data.model.AIStoryResponse
import com.mamababa.stories.data.model.Story
import com.mamababa.stories.data.model.VoiceModel
import com.mamababa.stories.data.repository.AIStoryRepository
import com.mamababa.stories.data.repository.VoiceRepository
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

data class AICreateUiState(
    val themes: List<String> = AIStoryRequest.THEMES,
    val selectedTheme: String = "",
    val character: String = "",
    val childName: String = "",
    val ageMin: Int = 3,
    val ageMax: Int = 6,
    val styles: List<Pair<String, String>> = AIStoryRequest.STYLES,
    val selectedStyle: String = "warm",
    val lengths: List<Pair<String, String>> = AIStoryRequest.LENGTHS,
    val selectedLength: String = "medium",
    val voices: List<VoiceModel> = emptyList(),
    val selectedVoiceId: String = "",
    val extraPrompt: String = "",
    val isGenerating: Boolean = false,
    val generationProgress: Float = 0f,
    val generatedStory: AIStoryResponse? = null,
    val generatedStoryObj: Story? = null,
    val error: String? = null,
    val canGenerate: Boolean = false
)

class AICreateViewModel(
    private val aiRepository: AIStoryRepository = AIStoryRepository(),
    private val voiceRepository: VoiceRepository = VoiceRepository()
) : ViewModel() {

    private val _uiState = MutableStateFlow(AICreateUiState())
    val uiState: StateFlow<AICreateUiState> = _uiState.asStateFlow()

    private var generateJob: Job? = null

    init {
        loadVoices()
    }

    private fun loadVoices() {
        viewModelScope.launch {
            voiceRepository.getVoiceModels().collect { result ->
                result.onSuccess { voices ->
                    val readyVoices = voices.filter { it.status == com.mamababa.stories.data.model.VoiceModelStatus.READY }
                    _uiState.update {
                        it.copy(
                            voices = readyVoices,
                            selectedVoiceId = readyVoices.firstOrNull()?.id ?: ""
                        )
                    }
                    updateCanGenerate()
                }
            }
        }
    }

    fun selectTheme(theme: String) {
        _uiState.update { it.copy(selectedTheme = theme) }
        updateCanGenerate()
    }

    fun setCharacter(name: String) {
        _uiState.update { it.copy(character = name) }
        updateCanGenerate()
    }

    fun setChildName(name: String) {
        _uiState.update { it.copy(childName = name) }
    }

    fun setAgeRange(min: Int, max: Int) {
        _uiState.update { it.copy(ageMin = min, ageMax = max) }
    }

    fun selectStyle(style: String) {
        _uiState.update { it.copy(selectedStyle = style) }
    }

    fun selectLength(length: String) {
        _uiState.update { it.copy(selectedLength = length) }
    }

    fun selectVoice(voiceId: String) {
        _uiState.update { it.copy(selectedVoiceId = voiceId) }
    }

    fun setExtraPrompt(prompt: String) {
        _uiState.update { it.copy(extraPrompt = prompt) }
    }

    private fun updateCanGenerate() {
        val state = _uiState.value
        val canGenerate = state.selectedTheme.isNotEmpty() && !state.isGenerating
        _uiState.update { it.copy(canGenerate = canGenerate) }
    }

    fun generate() {
        if (!_uiState.value.canGenerate) return

        generateJob?.cancel()
        val state = _uiState.value

        val request = AIStoryRequest(
            theme = state.selectedTheme,
            character = state.character,
            ageMin = state.ageMin,
            ageMax = state.ageMax,
            style = state.selectedStyle,
            length = state.selectedLength,
            voiceModelId = state.selectedVoiceId,
            childName = state.childName,
            extraPrompt = state.extraPrompt
        )

        _uiState.update {
            it.copy(isGenerating = true, error = null, generatedStory = null, generationProgress = 0f)
        }

        generateJob = viewModelScope.launch {
            aiRepository.createStory(request).collect { result ->
                result.onSuccess { response ->
                    val progress = if (response.status == "completed") 1f
                    else (response.textContent.length / 500f).coerceIn(0.1f, 0.95f)

                    _uiState.update {
                        it.copy(
                            generatedStory = response,
                            generationProgress = progress,
                            isGenerating = response.status != "completed"
                        )
                    }

                    if (response.status == "completed") {
                        val voice = state.voices.firstOrNull { it.id == state.selectedVoiceId }
                        val story = Story(
                            id = response.storyId,
                            title = response.title,
                            author = "AI 创作",
                            description = "为宝贝定制的专属故事",
                            categoryRaw = "fairy",
                            tags = listOf("原创", "AI"),
                            ageMin = state.ageMin,
                            ageMax = state.ageMax,
                            durationSec = response.durationSec,
                            textContent = response.textContent,
                            voiceModelId = state.selectedVoiceId,
                            voiceName = voice?.name ?: "AI 声音",
                            sourceRaw = "ai"
                        )
                        _uiState.update { it.copy(generatedStoryObj = story) }
                    }
                }.onFailure { e ->
                    _uiState.update { it.copy(isGenerating = false, error = e.message) }
                }
            }
        }
    }

    fun playGeneratedStory() {
        val story = _uiState.value.generatedStoryObj ?: return
        com.mamababa.stories.MamaBabaStoriesApp.getInstance()
            .audioPlayerManager.playStory(story)
    }

    fun resetGeneration() {
        generateJob?.cancel()
        _uiState.update {
            it.copy(
                isGenerating = false,
                generatedStory = null,
                generatedStoryObj = null,
                generationProgress = 0f
            )
        }
    }

    override fun onCleared() {
        super.onCleared()
        generateJob?.cancel()
    }
}
