package com.mamababa.stories.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.mamababa.stories.ui.theme.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlin.math.abs
import kotlin.random.Random

/**
 * 实时波形视图
 * 用于录音时显示音量波形
 */
@Composable
fun WaveformView(
    amplitudes: List<Float>,
    modifier: Modifier = Modifier,
    barColor: Color = MaterialTheme.colorScheme.primary,
    barWidth: Float = 4f,
    barGap: Float = 3f,
    isRecording: Boolean = false,
    mirror: Boolean = true
) {
    val color = barColor

    Canvas(
        modifier = modifier.fillMaxWidth()
    ) {
        val canvasWidth = size.width
        val canvasHeight = size.height
        val centerY = canvasHeight / 2f
        val barCount = (canvasWidth / (barWidth + barGap)).toInt().coerceAtLeast(1)

        // 取最近的 barCount 个振幅点
        val displayAmplitudes = if (amplitudes.size >= barCount) {
            amplitudes.takeLast(barCount)
        } else {
            // 前面补 0
            List(barCount - amplitudes.size) { 0f } + amplitudes
        }

        displayAmplitudes.forEachIndexed { index, amp ->
            val x = index * (barWidth + barGap)
            val barHeight = (amp * canvasHeight * 0.85f).coerceAtLeast(3f)
            val top = if (mirror) centerY - barHeight / 2 else centerY - barHeight
            val height = if (mirror) barHeight else barHeight

            drawRoundRect(
                color = color,
                topLeft = Offset(x, top),
                size = Size(barWidth, height),
                cornerRadius = CornerRadius(barWidth / 2, barWidth / 2)
            )
        }
    }
}

/**
 * 静态波形（用于播放器显示进度）
 */
@Composable
fun StaticWaveform(
    progress: Float,
    modifier: Modifier = Modifier,
    barCount: Int = 60,
    playedColor: Color = MaterialTheme.colorScheme.primary,
    unplayedColor: Color = MaterialTheme.colorScheme.surfaceVariant,
    barWidth: Float = 3f,
    barGap: Float = 2f
) {
    // 生成固定的波形数据（随机但稳定）
    val waveformData = remember(barCount) {
        List(barCount) { i ->
            val base = 0.3f + 0.7f * abs(kotlin.math.sin(i * 0.35).toFloat())
            val variation = 0.2f * Random(i).nextFloat()
            (base + variation).coerceIn(0.2f, 1f)
        }
    }

    Canvas(modifier = modifier.fillMaxWidth()) {
        val canvasWidth = size.width
        val canvasHeight = size.height
        val centerY = canvasHeight / 2f
        val totalBarWidth = barWidth + barGap
        val playedBars = (progress * barCount).toInt()

        waveformData.forEachIndexed { index, amp ->
            val x = index * totalBarWidth
            val barHeight = (amp * canvasHeight * 0.85f).coerceAtLeast(4f)
            val color = if (index <= playedBars) playedColor else unplayedColor

            drawRoundRect(
                color = color,
                topLeft = Offset(x, centerY - barHeight / 2),
                size = Size(barWidth, barHeight),
                cornerRadius = CornerRadius(barWidth / 2, barWidth / 2)
            )
        }
    }
}

/**
 * 录音时的动态波形（自动模拟动画）
 */
@Composable
fun AnimatedWaveform(
    isActive: Boolean,
    modifier: Modifier = Modifier,
    color: Color = MaterialTheme.colorScheme.primary
) {
    var amplitudes by remember { mutableStateOf(listOf<Float>()) }

    LaunchedEffect(isActive) {
        if (isActive) {
            while (isActive) {
                val newAmp = if (isActive) {
                    // 模拟音量波动
                    (0.3f + 0.7f * Random.nextFloat()) * (0.5f + 0.5f * Random.nextFloat())
                } else 0f
                amplitudes = (amplitudes + newAmp).takeLast(80)
                delay(60)
            }
        } else {
            amplitudes = emptyList()
        }
    }

    WaveformView(
        amplitudes = amplitudes,
        modifier = modifier,
        barColor = color,
        isRecording = isActive
    )
}
