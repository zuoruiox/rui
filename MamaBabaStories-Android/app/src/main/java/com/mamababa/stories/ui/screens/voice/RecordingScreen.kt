package com.mamababa.stories.ui.screens.voice

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mamababa.stories.service.audio.RecordingQuality
import com.mamababa.stories.ui.components.WaveformView
import com.mamababa.stories.ui.theme.*
import com.mamababa.stories.util.Constants
import com.mamababa.stories.util.formatDuration
import com.mamababa.stories.viewmodel.VoiceCloneViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RecordingScreen(
    voiceId: String,
    onBack: () -> Unit,
    onComplete: () -> Unit
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val viewModel = remember { VoiceCloneViewModel(context) }
    val uiState by viewModel.uiState.collectAsState()
    val recState = uiState.recordingState

    val targetDurationMs = Constants.RECORDING_TARGET_DURATION_MS
    val progress = (recState.durationMs.toFloat() / targetDurationMs).coerceIn(0f, 1f)
    val animatedProgress by animateFloatAsState(targetValue = progress, label = "recProgress")

    val qualityColor = when (recState.quality) {
        RecordingQuality.GOOD -> Success
        RecordingQuality.TOO_LOUD -> Error
        RecordingQuality.TOO_QUIET -> Warning
        RecordingQuality.NOISY -> Warning
    }
    val qualityText = when (recState.quality) {
        RecordingQuality.GOOD -> "音质良好"
        RecordingQuality.TOO_LOUD -> "声音过大，请离麦克风远一点"
        RecordingQuality.TOO_QUIET -> "声音过小，请靠近麦克风"
        RecordingQuality.NOISY -> "环境嘈杂，请找安静的地方"
    }

    // 录制完成自动跳转
    LaunchedEffect(uiState.isTraining, uiState.completedMessage) {
        if (uiState.completedMessage != null) {
            kotlinx.coroutines.delay(1500)
            onComplete()
        }
    }

    // 提示朗读文本
    val sampleTexts = remember {
        listOf(
            "从前，在一片美丽的大森林里，住着一只可爱的小兔子。",
            "小兔子有一双长长的耳朵，一双红红的眼睛。",
            "有一天，小兔子在森林里遇到了小松鼠。",
            "他们一起采蘑菇，一起玩耍，成为了好朋友。",
            "晚上，小兔子回到家，做了一个甜甜的梦。"
        )
    }
    val currentTextIndex = (recState.durationMs / 30000).toInt().coerceIn(0, sampleTexts.size - 1)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("录制声音") },
                navigationIcon = {
                    IconButton(onClick = {
                        viewModel.cancelRecording()
                        onBack()
                    }) {
                        Icon(Icons.Filled.Close, contentDescription = "关闭")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .background(MaterialTheme.colorScheme.background)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Spacer(modifier = Modifier.height(16.dp))

                // 进度环
                Box(contentAlignment = Alignment.Center) {
                    // 背景环
                    CircularProgressIndicator(
                        progress = { 1f },
                        modifier = Modifier.size(220.dp),
                        strokeWidth = 10.dp,
                        color = MaterialTheme.colorScheme.surfaceVariant,
                        trackColor = MaterialTheme.colorScheme.surfaceVariant
                    )
                    // 进度环
                    CircularProgressIndicator(
                        progress = { animatedProgress },
                        modifier = Modifier.size(220.dp),
                        strokeWidth = 10.dp,
                        color = MaterialTheme.colorScheme.primary,
                        trackColor = Color.Transparent
                    )
                    // 中心内容
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        if (uiState.isTraining || uiState.isUploading) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(40.dp),
                                color = MaterialTheme.colorScheme.primary,
                                strokeWidth = 3.dp
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = if (uiState.isUploading) "上传中…"
                                else "训练中 ${uiState.trainingProgress}%",
                                style = MaterialTheme.typography.titleMedium,
                                color = MaterialTheme.colorScheme.onBackground
                            )
                        } else {
                            Text(
                                text = recState.durationMs.formatDuration(),
                                style = MaterialTheme.typography.displaySmall.copy(fontWeight = FontWeight.Bold),
                                color = MaterialTheme.colorScheme.onBackground
                            )
                            Text(
                                text = "目标 3:00",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(24.dp))

                // 质量提示
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = qualityColor.copy(alpha = 0.15f)
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = when (recState.quality) {
                                RecordingQuality.GOOD -> Icons.Filled.CheckCircle
                                RecordingQuality.TOO_LOUD -> Icons.Filled.VolumeUp
                                RecordingQuality.TOO_QUIET -> Icons.Filled.VolumeMute
                                RecordingQuality.NOISY -> Icons.Filled.SurroundSound
                            },
                            contentDescription = null,
                            tint = qualityColor,
                            modifier = Modifier.size(18.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = qualityText,
                            style = MaterialTheme.typography.bodySmall,
                            color = qualityColor
                        )
                    }
                }

                Spacer(modifier = Modifier.height(24.dp))

                // 朗读文本提示
                if (recState.isRecording && !uiState.isTraining && !uiState.isUploading) {
                    Surface(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        color = MaterialTheme.colorScheme.surfaceVariant
                    ) {
                        Text(
                            text = "请朗读：\n\n${sampleTexts[currentTextIndex]}",
                            style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(16.dp),
                            textAlign = TextAlign.Center
                        )
                    }
                    Spacer(modifier = Modifier.height(16.dp))
                }

                // 波形
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(100.dp)
                        .clip(RoundedCornerShape(16.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant),
                    contentAlignment = Alignment.Center
                ) {
                    WaveformView(
                        amplitudes = recState.amplitudeHistory,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp),
                        barColor = MaterialTheme.colorScheme.primary,
                        isRecording = recState.isRecording
                    )
                }

                Spacer(modifier = Modifier.weight(1f))

                // 控制按钮
                if (!uiState.isTraining && !uiState.isUploading) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(bottom = 24.dp),
                        horizontalArrangement = Arrangement.SpaceEvenly,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        if (!recState.isRecording) {
                            // 初始状态：显示开始按钮
                            Spacer(modifier = Modifier.size(64.dp))
                            Spacer(modifier = Modifier.weight(1f))
                            // 录制按钮
                            Surface(
                                modifier = Modifier.size(80.dp),
                                shape = CircleShape,
                                color = MaterialTheme.colorScheme.primary,
                                shadowElevation = 8.dp,
                                onClick = { viewModel.startRecording() }
                            ) {
                                Box(contentAlignment = Alignment.Center) {
                                    Icon(
                                        imageVector = Icons.Filled.FiberManualRecord,
                                        contentDescription = "开始录制",
                                        tint = Color.White,
                                        modifier = Modifier.size(36.dp)
                                    )
                                }
                            }
                            Spacer(modifier = Modifier.weight(1f))
                            Spacer(modifier = Modifier.size(64.dp))
                        } else {
                            // 录制中：暂停/停止
                            Surface(
                                modifier = Modifier.size(56.dp),
                                shape = CircleShape,
                                color = MaterialTheme.colorScheme.surfaceVariant,
                                onClick = {
                                    if (recState.isPaused) viewModel.resumeRecording()
                                    else viewModel.pauseRecording()
                                }
                            ) {
                                Box(contentAlignment = Alignment.Center) {
                                    Icon(
                                        imageVector = if (recState.isPaused) Icons.Filled.PlayArrow
                                        else Icons.Filled.Pause,
                                        contentDescription = if (recState.isPaused) "继续" else "暂停",
                                        tint = MaterialTheme.colorScheme.onSurface,
                                        modifier = Modifier.size(28.dp)
                                    )
                                }
                            }

                            Spacer(modifier = Modifier.width(24.dp))

                            // 停止/完成按钮
                            val canFinish = recState.durationMs >= Constants.RECORDING_MIN_DURATION_MS
                            Surface(
                                modifier = Modifier.size(80.dp),
                                shape = CircleShape,
                                color = if (canFinish) MaterialTheme.colorScheme.primary
                                else MaterialTheme.colorScheme.surfaceVariant,
                                shadowElevation = if (canFinish) 8.dp else 0.dp,
                                onClick = {
                                    if (canFinish) {
                                        viewModel.stopRecording()
                                    }
                                }
                            ) {
                                Box(contentAlignment = Alignment.Center) {
                                    Icon(
                                        imageVector = Icons.Filled.Stop,
                                        contentDescription = "完成",
                                        tint = if (canFinish) Color.White
                                        else MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.size(32.dp)
                                    )
                                }
                            }

                            Spacer(modifier = Modifier.width(24.dp))

                            // 删除按钮
                            Surface(
                                modifier = Modifier.size(56.dp),
                                shape = CircleShape,
                                color = MaterialTheme.colorScheme.errorContainer,
                                onClick = {
                                    viewModel.cancelRecording()
                                    onBack()
                                }
                            ) {
                                Box(contentAlignment = Alignment.Center) {
                                    Icon(
                                        imageVector = Icons.Filled.Delete,
                                        contentDescription = "取消",
                                        tint = MaterialTheme.colorScheme.error,
                                        modifier = Modifier.size(24.dp)
                                    )
                                }
                            }
                        }
                    }

                    if (recState.durationMs < Constants.RECORDING_MIN_DURATION_MS && recState.isRecording) {
                        Text(
                            text = "请至少录制 1 分钟",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.padding(bottom = 16.dp)
                        )
                    }
                } else {
                    // 训练/上传中提示
                    Text(
                        text = "请稍候，AI 正在学习你的声音…",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(bottom = 32.dp)
                    )
                }
            }
        }
    }
}
