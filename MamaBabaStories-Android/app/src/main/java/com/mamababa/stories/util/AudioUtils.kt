package com.mamababa.stories.util

import android.media.AudioFormat
import android.media.MediaRecorder
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.log10
import kotlin.math.sqrt

/**
 * 音频工具类
 */
object AudioUtils {

    /**
     * 计算 PCM 数据的 RMS（均方根）能量
     * @param data PCM 16bit 数据
     * @param size 有效数据长度（字节）
     */
    fun calculateRms(data: ByteArray, size: Int): Double {
        var sum = 0.0
        var samples = 0
        var i = 0
        while (i < size - 1) {
            val sample = (data[i + 1].toInt() shl 8) or (data[i].toInt() and 0xFF)
            sum += (sample * sample).toDouble()
            samples++
            i += 2
        }
        return if (samples > 0) sqrt(sum / samples) else 0.0
    }

    /**
     * 将 RMS 转换为分贝值 (dBFS)
     */
    fun rmsToDb(rms: Double): Double {
        return if (rms > 0) 20 * log10(rms / Short.MAX_VALUE.toDouble()) else -100.0
    }

    /**
     * 归一化音量到 0-1 范围，用于波形显示
     */
    fun normalizeVolume(rms: Double): Float {
        val db = rmsToDb(rms)
        // -60dB ~ 0dB 映射到 0~1
        return ((db + 60) / 60).coerceIn(0.0, 1.0).toFloat()
    }

    /**
     * 检测是否削波（声音过大）
     */
    fun isClipping(data: ByteArray, size: Int): Boolean {
        var i = 0
        while (i < size - 1) {
            val sample = (data[i + 1].toInt() shl 8) or (data[i].toInt() and 0xFF)
            if (abs(sample) > Constants.CLIPPING_THRESHOLD) return true
            i += 2
        }
        return false
    }

    /**
     * 检测是否静音
     */
    fun isSilence(rms: Double): Boolean = rms < Constants.SILENCE_THRESHOLD

    /**
     * 检测是否有语音（VAD）
     */
    fun isSpeech(rms: Double): Boolean = rms > Constants.VAD_ENERGY_THRESHOLD

    /**
     * 计算录音质量评分 0-100
     */
    fun calculateQualityScore(rmsHistory: List<Double>, clippingCount: Int, silenceRatio: Double): Int {
        val avgRms = if (rmsHistory.isNotEmpty()) rmsHistory.average() else 0.0
        val volumeScore = when {
            avgRms < 1000 -> 40   // 太小声
            avgRms > 25000 -> 50  // 太大声
            avgRms in 3000.0..15000.0 -> 100
            else -> 75
        }
        val clippingScore = (100 - (clippingCount * 5).coerceAtMost(50))
        val silenceScore = ((1 - silenceRatio) * 100).toInt().coerceIn(0, 100)
        return (volumeScore * 0.4 + clippingScore * 0.3 + silenceScore * 0.3).toInt()
            .coerceIn(0, 100)
    }

    /**
     * 获取最小缓冲区大小
     */
    fun getMinBufferSize(sampleRate: Int = Constants.SAMPLE_RATE): Int {
        return android.media.AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
    }

    /**
     * 创建 AudioRecord 实例
     */
    fun createAudioRecord(sampleRate: Int = Constants.SAMPLE_RATE): android.media.AudioRecord {
        val bufferSize = maxOf(
            getMinBufferSize(sampleRate),
            sampleRate * 2 * 2 // 2 秒缓冲
        )
        return android.media.AudioRecord(
            MediaRecorder.AudioSource.MIC,
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize
        )
    }

    /**
     * 将 PCM 数据写入 WAV 文件
     * WAV 格式：RIFF header + fmt chunk + data chunk
     */
    @Throws(IOException::class)
    fun writeWavFile(
        outFile: File,
        pcmData: ByteArray,
        sampleRate: Int = Constants.SAMPLE_RATE,
        channels: Int = Constants.CHANNEL_COUNT,
        bitsPerSample: Int = Constants.BITS_PER_SAMPLE
    ) {
        val totalDataLen = pcmData.size.toLong()
        val byteRate = sampleRate * channels * bitsPerSample / 8L
        val blockAlign = (channels * bitsPerSample / 8)
        val totalFileLen = totalDataLen + 36

        FileOutputStream(outFile).use { fos ->
            val buffer = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
            // RIFF header
            buffer.put("RIFF".toByteArray())
            buffer.putInt(totalFileLen.toInt())
            buffer.put("WAVE".toByteArray())
            // fmt chunk
            buffer.put("fmt ".toByteArray())
            buffer.putInt(16) // chunk size
            buffer.putShort(1) // PCM format
            buffer.putShort(channels.toShort())
            buffer.putInt(sampleRate)
            buffer.putInt(byteRate.toInt())
            buffer.putShort(blockAlign.toShort())
            buffer.putShort(bitsPerSample.toShort())
            // data chunk
            buffer.put("data".toByteArray())
            buffer.putInt(totalDataLen.toInt())

            fos.write(buffer.array())
            fos.write(pcmData)
            fos.flush()
        }
    }

    /**
     * 生成录音文件名
     */
    fun generateRecordingFileName(): String {
        val ts = System.currentTimeMillis()
        return "voice_sample_$ts.wav"
    }

    /**
     * 获取录音目录
     */
    fun getRecordingDir(context: Context): File {
        val dir = File(context.filesDir, Constants.RECORD_DIR)
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    /**
     * 获取故事下载目录
     */
    fun getStoriesDir(context: Context): File {
        val dir = File(context.filesDir, Constants.DOWNLOAD_DIR)
        if (!dir.exists()) dir.mkdirs()
        return dir
    }
}
