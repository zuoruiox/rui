package com.mamababa.stories.service.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.os.Build
import com.mamababa.stories.util.AudioUtils
import com.mamababa.stories.util.Constants
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 录音质量状态
 */
enum class RecordingQuality {
    GOOD, TOO_LOUD, TOO_QUIET, NOISY
}

/**
 * 录音状态
 */
data class RecordingState(
    val isRecording: Boolean = false,
    val isPaused: Boolean = false,
    val durationMs: Long = 0L,
    val currentVolume: Float = 0f,       // 0-1 归一化音量
    val quality: RecordingQuality = RecordingQuality.GOOD,
    val clippingCount: Int = 0,
    val silenceRatio: Float = 0f,
    val amplitudeHistory: List<Float> = emptyList(), // 波形数据
    val outputFile: File? = null,
    val error: String? = null
)

/**
 * 音频录音器
 * 使用 AudioRecord 进行实时 PCM 录音，支持音量检测、VAD、质量检测
 */
class AudioRecorder(private val context: Context) {

    private val _state = MutableStateFlow(RecordingState())
    val state: StateFlow<RecordingState> = _state.asStateFlow()

    private var audioRecord: AudioRecord? = null
    private var recordingJob: Job? = null
    private var isRecording = AtomicBoolean(false)
    private var isPaused = AtomicBoolean(false)
    private var pcmBuffer = ByteArrayOutputStream()
    private var startTs = 0L
    private var pausedDurationMs = 0L
    private var pauseStartTs = 0L

    private var totalSamples = 0L
    private var silenceSamples = 0L
    private var clippingCount = 0

    // 波形历史（固定长度）
    private val maxAmplitudePoints = 80
    private val amplitudeList = mutableListOf<Float>()

    private val audioManager: AudioManager by lazy {
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }

    // 音频焦点
    private var focusRequest: AudioFocusRequest? = null
    private val focusLock = Any()
    private var hasAudioFocus = false

    private val audioFocusChangeListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_GAIN -> {
                // 恢复录音
            }
            AudioManager.AUDIOFOCUS_LOSS -> {
                stopRecording()
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                pauseRecording()
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                // 录音不需要降低音量
            }
        }
    }

    /**
     * 请求音频焦点
     */
    private fun requestAudioFocus(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                .setOnAudioFocusChangeListener(audioFocusChangeListener)
                .build()
            focusRequest = request
            audioManager.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                audioFocusChangeListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
            ) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
    }

    /**
     * 释放音频焦点
     */
    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(audioFocusChangeListener)
        }
        hasAudioFocus = false
    }

    /**
     * 开始录音
     */
    fun startRecording(outputFile: File? = null) {
        if (isRecording.get()) return

        if (!requestAudioFocus()) {
            _state.value = _state.value.copy(error = "无法获取音频焦点")
            return
        }

        val record = AudioUtils.createAudioRecord()
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            _state.value = _state.value.copy(error = "录音器初始化失败")
            return
        }
        audioRecord = record

        // 重置状态
        pcmBuffer = ByteArrayOutputStream()
        startTs = System.currentTimeMillis()
        pausedDurationMs = 0L
        totalSamples = 0L
        silenceSamples = 0L
        clippingCount = 0
        amplitudeList.clear()
        isRecording.set(true)
        isPaused.set(false)

        val outFile = outputFile ?: run {
            File(AudioUtils.getRecordingDir(context), AudioUtils.generateRecordingFileName())
        }

        _state.value = RecordingState(
            isRecording = true,
            outputFile = outFile
        )

        record.startRecording()

        recordingJob = CoroutineScope(Dispatchers.IO).launch {
            val bufferSize = AudioUtils.getMinBufferSize()
            val buffer = ByteArray(bufferSize)
            var lastAmplitudeUpdate = 0L

            try {
                while (isRecording.get() && isActive) {
                    if (isPaused.get()) {
                        delay(50)
                        continue
                    }

                    val read = record.read(buffer, 0, bufferSize)
                    if (read <= 0) continue

                    pcmBuffer.write(buffer, 0, read)

                    // 计算音量
                    val rms = AudioUtils.calculateRms(buffer, read)
                    val volume = AudioUtils.normalizeVolume(rms)

                    // 质量检测
                    val isClipping = AudioUtils.isClipping(buffer, read)
                    val isSilence = AudioUtils.isSilence(rms)
                    if (isClipping) clippingCount++
                    totalSamples += read / 2
                    if (isSilence) silenceSamples += read / 2

                    val quality = when {
                        isClipping -> RecordingQuality.TOO_LOUD
                        rms < 500 -> RecordingQuality.TOO_QUIET
                        rms < 1500 && volume < 0.1f -> RecordingQuality.NOISY
                        else -> RecordingQuality.GOOD
                    }

                    // 更新波形（每 50ms 一个点）
                    val now = System.currentTimeMillis()
                    if (now - lastAmplitudeUpdate > 50) {
                        lastAmplitudeUpdate = now
                        amplitudeList.add(volume)
                        if (amplitudeList.size > maxAmplitudePoints) {
                            amplitudeList.removeAt(0)
                        }
                    }

                    val elapsed = now - startTs - pausedDurationMs
                    val silenceRatio = if (totalSamples > 0) silenceSamples.toFloat() / totalSamples else 0f

                    _state.value = _state.value.copy(
                        isRecording = true,
                        durationMs = elapsed,
                        currentVolume = volume,
                        quality = quality,
                        clippingCount = clippingCount,
                        silenceRatio = silenceRatio,
                        amplitudeHistory = amplitudeList.toList()
                    )

                    // 达到最大时长自动停止
                    if (elapsed >= Constants.RECORDING_MAX_DURATION_MS) {
                        stopRecording()
                        break
                    }
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _state.value = _state.value.copy(error = e.message)
            }
        }
    }

    /**
     * 暂停录音
     */
    fun pauseRecording() {
        if (!isRecording.get() || isPaused.get()) return
        isPaused.set(true)
        pauseStartTs = System.currentTimeMillis()
        _state.value = _state.value.copy(isPaused = true)
    }

    /**
     * 恢复录音
     */
    fun resumeRecording() {
        if (!isRecording.get() || !isPaused.get()) return
        pausedDurationMs += System.currentTimeMillis() - pauseStartTs
        isPaused.set(false)
        _state.value = _state.value.copy(isPaused = false)
    }

    /**
     * 停止录音并保存 WAV 文件
     * @return 保存的文件和时长秒数
     */
    fun stopRecording(): Pair<File?, Int> {
        if (!isRecording.get()) return null to 0
        isRecording.set(false)
        isPaused.set(false)

        try {
            audioRecord?.stop()
        } catch (_: Exception) {}
        audioRecord?.release()
        audioRecord = null

        recordingJob?.cancel()
        recordingJob = null

        abandonAudioFocus()

        val durationSec = ((System.currentTimeMillis() - startTs - pausedDurationMs) / 1000).toInt()
        val outFile = _state.value.outputFile
        val pcmData = pcmBuffer.toByteArray()

        // 保存 WAV
        if (outFile != null && pcmData.isNotEmpty() && durationSec >= 1) {
            try {
                AudioUtils.writeWavFile(outFile, pcmData)
            } catch (e: Exception) {
                _state.value = _state.value.copy(error = "保存文件失败: ${e.message}")
            }
        }

        _state.value = _state.value.copy(
            isRecording = false,
            isPaused = false,
            durationMs = durationSec * 1000L
        )

        return outFile to durationSec
    }

    /**
     * 取消录音（不保存）
     */
    fun cancelRecording() {
        if (!isRecording.get()) return
        isRecording.set(false)
        isPaused.set(false)

        try {
            audioRecord?.stop()
        } catch (_: Exception) {}
        audioRecord?.release()
        audioRecord = null

        recordingJob?.cancel()
        recordingJob = null

        abandonAudioFocus()

        // 删除已录制的文件
        _state.value.outputFile?.delete()

        _state.value = RecordingState()
    }

    /**
     * 获取当前录音质量评分
     */
    fun getQualityScore(): Int {
        val s = _state.value
        return AudioUtils.calculateQualityScore(
            rmsHistory = emptyList(),
            clippingCount = s.clippingCount,
            silenceRatio = s.silenceRatio.toDouble()
        )
    }

    fun release() {
        cancelRecording()
    }
}
