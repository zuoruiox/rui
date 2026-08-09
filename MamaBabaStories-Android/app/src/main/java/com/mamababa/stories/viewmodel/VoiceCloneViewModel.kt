package com.mamababa.stories.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mamababa.stories.data.model.VoiceModel
import com.mamababa.stories.data.model.VoiceModelStatus
import com.mamababa.stories.data.model.VoiceTrainRequest
import com.mamababa.stories.data.repository.VoiceRepository
import com.mamababa.stories.service.audio.AudioRecorder
import com.mamababa.stories.service.audio.RecordingQuality
import com.mamababa.stories.service.audio.RecordingState
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.io.File

data class VoiceCloneUiState(
    val voices: List<VoiceModel> = emptyList(),
    val isLoading: Boolean = true,
    val isRecording: Boolean = false,
    val isPaused: Boolean = false,
    val isUploading: Boolean = false,
    val isTraining: Boolean = false,
    val trainingProgress: Int = 0,
    val recordingState: RecordingState = RecordingState(),
    val selectedVoiceType: String = "mom",
    val voiceName: String = "妈妈的声音",
    val error: String? = null,
    val showNameDialog: Boolean = false,
    val pendingFile: File? = null,
    val pendingDuration: Int = 0,
    val completedMessage: String? = null
)

class VoiceCloneViewModel(
    context: Context,
    private val voiceRepository: VoiceRepository = VoiceRepository()
) : ViewModel() {

    private val audioRecorder = AudioRecorder(context)

    private val _uiState = MutableStateFlow(VoiceCloneUiState())
    val uiState: StateFlow<VoiceCloneUiState> = _uiState.asStateFlow()

    init {
        loadVoices()
        // 监听录音状态
        viewModelScope.launch {
            audioRecorder.state.collect { recState ->
                _uiState.update {
                    it.copy(
                        recordingState = recState,
                        isRecording = recState.isRecording,
                        isPaused = recState.isPaused
                    )
                }
            }
        }
    }

    fun loadVoices() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            voiceRepository.getVoiceModels().collect { result ->
                result.onSuccess { voices ->
                    _uiState.update { it.copy(voices = voices, isLoading = false) }
                }.onFailure { e ->
                    _uiState.update { it.copy(isLoading = false, error = e.message) }
                }
            }
        }
    }

    fun selectVoiceType(type: String) {
        val name = when (type) {
            "mom" -> "妈妈的声音"
            "dad" -> "爸爸的声音"
            "grandma" -> "奶奶的声音"
            "grandpa" -> "爷爷的声音"
            else -> "自定义声音"
        }
        _uiState.update { it.copy(selectedVoiceType = type, voiceName = name) }
    }

    fun setVoiceName(name: String) {
        _uiState.update { it.copy(voiceName = name) }
    }

    fun showNameDialog(show: Boolean) {
        _uiState.update { it.copy(showNameDialog = show) }
    }

    fun startRecording() {
        audioRecorder.startRecording()
    }

    fun pauseRecording() = audioRecorder.pauseRecording()
    fun resumeRecording() = audioRecorder.resumeRecording()

    fun stopRecording() {
        val (file, duration) = audioRecorder.stopRecording()
        if (file != null && duration >= 30) {
            _uiState.update { it.copy(pendingFile = file, pendingDuration = duration) }
            uploadAndTrain(file, duration)
        } else {
            _uiState.update { it.copy(error = "录音时间太短，请至少录制 30 秒") }
        }
    }

    fun cancelRecording() {
        audioRecorder.cancelRecording()
    }

    private fun uploadAndTrain(file: File, durationSec: Int) {
        viewModelScope.launch {
            _uiState.update { it.copy(isUploading = true, error = null) }

            val uploadResult = voiceRepository.uploadVoiceSample(
                name = _uiState.value.voiceName,
                file = file,
                durationSec = durationSec
            )

            uploadResult.onSuccess { upload ->
                _uiState.update { it.copy(isUploading = false, isTraining = true, trainingProgress = 0) }

                val trainRequest = VoiceTrainRequest(
                    name = _uiState.value.voiceName,
                    ownerType = _uiState.value.selectedVoiceType,
                    audioFileIds = listOf(upload.fileId)
                )

                voiceRepository.trainVoice(trainRequest).collect { result ->
                    result.onSuccess { voice ->
                        _uiState.update {
                            it.copy(
                                trainingProgress = voice.progress,
                                isTraining = voice.status == VoiceModelStatus.TRAINING
                            )
                        }
                        if (voice.status == VoiceModelStatus.READY) {
                            _uiState.update {
                                it.copy(
                                    isTraining = false,
                                    trainingProgress = 100,
                                    completedMessage = "声音模型训练完成！",
                                    pendingFile = null,
                                    pendingDuration = 0
                                )
                            }
                            loadVoices()
                        }
                    }.onFailure { e ->
                        _uiState.update {
                            it.copy(isTraining = false, error = "训练失败: ${e.message}")
                        }
                    }
                }
            }.onFailure { e ->
                _uiState.update { it.copy(isUploading = false, error = "上传失败: ${e.message}") }
            }
        }
    }

    fun deleteVoice(voice: VoiceModel) {
        viewModelScope.launch {
            voiceRepository.deleteVoice(voice.id)
            loadVoices()
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    fun clearCompletedMessage() {
        _uiState.update { it.copy(completedMessage = null) }
    }

    override fun onCleared() {
        super.onCleared()
        audioRecorder.release()
    }
}
