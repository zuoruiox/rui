package com.mamababa.stories.ui.screens.player

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
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
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.mamababa.stories.data.model.TTSConfig
import com.mamababa.stories.ui.components.StaticWaveform
import com.mamababa.stories.ui.theme.*
import com.mamababa.stories.util.formatDuration
import com.mamababa.stories.viewmodel.PlayerViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StoryPlayerScreen(
    onBack: () -> Unit,
    viewModel: PlayerViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val story = uiState.story

    val progress by animateFloatAsState(targetValue = uiState.progress, label = "playerProgress")

    // 封面旋转动画
    val rotation by animateFloatAsState(
        targetValue = if (uiState.isPlaying) 360f else 0f,
        animationSpec = androidx.compose.animation.core.infiniteRepeatable(
            animation = androidx.compose.animation.core.tween(durationMillis = 20000, easing = androidx.compose.animation.core.LinearEasing),
            repeatMode = androidx.compose.animation.core.RepeatMode.Restart
        ),
        label = "coverRotation"
    )

    PlayerTheme {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        listOf(
                            MaterialTheme.colorScheme.primaryContainer,
                            MaterialTheme.colorScheme.background
                        )
                    )
                )
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .statusBarsPadding()
                    .navigationBarsPadding()
            ) {
                // 顶部栏
                TopAppBar(
                    title = {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(
                                text = "正在播放",
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    },
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(
                                imageVector = Icons.Filled.KeyboardArrowDown,
                                contentDescription = "返回",
                                tint = MaterialTheme.colorScheme.onBackground,
                                modifier = Modifier.size(32.dp)
                            )
                        }
                    },
                    actions = {
                        IconButton(onClick = { /* 更多 */ }) {
                            Icon(
                                imageVector = Icons.Filled.MoreVert,
                                contentDescription = "更多",
                                tint = MaterialTheme.colorScheme.onBackground
                            )
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = Color.Transparent
                    )
                )

                Spacer(modifier = Modifier.height(24.dp))

                // 封面
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f),
                    contentAlignment = Alignment.Center
                ) {
                    val gradient = when (story?.categoryRaw) {
                        "fairy" -> WarmGradient
                        "fable" -> listOf(TertiaryLight, Tertiary)
                        "lullaby" -> listOf(Color(0xFF3A3A5C), Tertiary)
                        else -> WarmGradient
                    }
                    Box(
                        modifier = Modifier
                            .size(280.dp)
                            .graphicsLayer {
                                rotationZ = if (uiState.isPlaying) rotation else 0f
                            }
                            .clip(CircleShape)
                            .background(Brush.radialGradient(gradient)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Filled.MenuBook,
                            contentDescription = null,
                            tint = Color.White.copy(alpha = 0.9f),
                            modifier = Modifier.size(100.dp)
                        )
                    }
                }

                Spacer(modifier = Modifier.height(24.dp))

                // 故事信息
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = story?.title ?: "选择一个故事开始播放",
                        style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold),
                        color = MaterialTheme.colorScheme.onBackground,
                        textAlign = TextAlign.Center,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = story?.voiceName ?: "",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                Spacer(modifier = Modifier.height(24.dp))

                // 波形进度
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 24.dp)
                ) {
                    StaticWaveform(
                        progress = progress,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(60.dp)
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null
                            ) { /* 点击波形跳转 */ },
                        playedColor = MaterialTheme.colorScheme.primary,
                        unplayedColor = MaterialTheme.colorScheme.surfaceVariant
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = uiState.currentPositionMs.formatDuration(),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = uiState.durationMs.formatDuration(),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                Spacer(modifier = Modifier.height(24.dp))

                // 控制按钮
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 24.dp),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(onClick = { viewModel.toggleSpeedMenu() }) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(
                                text = "${uiState.speed}x",
                                style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                                color = MaterialTheme.colorScheme.onBackground
                            )
                        }
                    }

                    IconButton(onClick = { viewModel.playPrevious() }) {
                        Icon(
                            imageVector = Icons.Filled.SkipPrevious,
                            contentDescription = "上一个",
                            tint = MaterialTheme.colorScheme.onBackground,
                            modifier = Modifier.size(36.dp)
                        )
                    }

                    // 播放/暂停大按钮
                    Surface(
                        modifier = Modifier.size(72.dp),
                        shape = CircleShape,
                        color = MaterialTheme.colorScheme.primary,
                        shadowElevation = 8.dp,
                        onClick = { viewModel.togglePlayPause() }
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(
                                imageVector = if (uiState.isPlaying) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                                contentDescription = if (uiState.isPlaying) "暂停" else "播放",
                                tint = MaterialTheme.colorScheme.onPrimary,
                                modifier = Modifier.size(40.dp)
                            )
                        }
                    }

                    IconButton(onClick = { viewModel.playNext() }) {
                        Icon(
                            imageVector = Icons.Filled.SkipNext,
                            contentDescription = "下一个",
                            tint = MaterialTheme.colorScheme.onBackground,
                            modifier = Modifier.size(36.dp)
                        )
                    }

                    IconButton(onClick = { viewModel.toggleTimerMenu() }) {
                        Icon(
                            imageVector = Icons.Filled.Bedtime,
                            contentDescription = "定时",
                            tint = if (uiState.isSleepTimerActive) MaterialTheme.colorScheme.primary
                            else MaterialTheme.colorScheme.onBackground,
                            modifier = Modifier.size(28.dp)
                        )
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                // 底部操作
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 32.dp),
                    horizontalArrangement = Arrangement.SpaceEvenly
                ) {
                    PlayerActionButton(
                        icon = Icons.Filled.FavoriteBorder,
                        text = "收藏",
                        onClick = { /* toggle like */ }
                    )
                    PlayerActionButton(
                        icon = Icons.Filled.Downloading,
                        text = "下载",
                        onClick = { /* download */ }
                    )
                    PlayerActionButton(
                        icon = Icons.Filled.Share,
                        text = "分享",
                        onClick = { /* share */ }
                    )
                    PlayerActionButton(
                        icon = Icons.Filled.Repeat,
                        text = if (uiState.repeatMode == 1) "单曲循环" else "循环",
                        selected = uiState.repeatMode == 1,
                        onClick = { viewModel.toggleRepeat() }
                    )
                }

                Spacer(modifier = Modifier.height(24.dp))
            }

            // 速度选择菜单
            if (uiState.showSpeedMenu) {
                SpeedMenu(
                    currentSpeed = uiState.speed,
                    onSpeedSelected = { viewModel.setSpeed(it); viewModel.dismissMenus() },
                    onDismiss = { viewModel.dismissMenus() }
                )
            }

            // 定时选择菜单
            if (uiState.showTimerMenu) {
                TimerMenu(
                    currentTimerMin = if (uiState.isSleepTimerActive) uiState.sleepTimerRemainingMin else -1,
                    onTimerSelected = { viewModel.setSleepTimer(it) },
                    onCancel = { viewModel.cancelSleepTimer(); viewModel.dismissMenus() },
                    onDismiss = { viewModel.dismissMenus() }
                )
            }
        }
    }
}

@Composable
private fun PlayerActionButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    text: String,
    onClick: () -> Unit,
    selected: Boolean = false
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.clickable(onClick = onClick)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = text,
            tint = if (selected) MaterialTheme.colorScheme.primary
            else MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.size(22.dp)
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = text,
            style = MaterialTheme.typography.labelSmall,
            color = if (selected) MaterialTheme.colorScheme.primary
            else MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun SpeedMenu(
    currentSpeed: Float,
    onSpeedSelected: (Float) -> Unit,
    onDismiss: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.4f))
            .clickable(onClick = onDismiss),
        contentAlignment = Alignment.BottomCenter
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(enabled = false) { },
            shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
            color = MaterialTheme.colorScheme.surface,
            tonalElevation = 8.dp
        ) {
            Column(modifier = Modifier.padding(vertical = 16.dp)) {
                Text(
                    text = "播放速度",
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                    modifier = Modifier.padding(horizontal = 24.dp, vertical = 8.dp)
                )
                Spacer(modifier = Modifier.height(8.dp))
                TTSConfig.SPEED_OPTIONS.forEach { speed ->
                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onSpeedSelected(speed) }
                            .padding(horizontal = 24.dp, vertical = 14.dp),
                        color = if (speed == currentSpeed)
                            MaterialTheme.colorScheme.primaryContainer
                        else Color.Transparent
                    ) {
                        Text(
                            text = "${speed}x",
                            style = MaterialTheme.typography.bodyLarge,
                            color = if (speed == currentSpeed)
                                MaterialTheme.colorScheme.primary
                            else MaterialTheme.colorScheme.onSurface
                        )
                    }
                }
                Spacer(modifier = Modifier.height(24.dp))
            }
        }
    }
}

@Composable
private fun TimerMenu(
    currentTimerMin: Long,
    onTimerSelected: (Long) -> Unit,
    onCancel: () -> Unit,
    onDismiss: () -> Unit
) {
    val options = listOf(15L, 30L, 45L, 60L, 90L)
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.4f))
            .clickable(onClick = onDismiss),
        contentAlignment = Alignment.BottomCenter
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(enabled = false) { },
            shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
            color = MaterialTheme.colorScheme.surface,
            tonalElevation = 8.dp
        ) {
            Column(modifier = Modifier.padding(vertical = 16.dp)) {
                Text(
                    text = "睡眠定时",
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                    modifier = Modifier.padding(horizontal = 24.dp, vertical = 8.dp)
                )
                if (currentTimerMin > 0) {
                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable(onClick = onCancel)
                            .padding(horizontal = 24.dp, vertical = 14.dp),
                        color = MaterialTheme.colorScheme.errorContainer
                    ) {
                        Text(
                            text = "关闭定时（剩余 ${currentTimerMin} 分钟）",
                            style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.error
                        )
                    }
                }
                options.forEach { min ->
                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onTimerSelected(min) }
                            .padding(horizontal = 24.dp, vertical = 14.dp),
                        color = if (min == currentTimerMin)
                            MaterialTheme.colorScheme.primaryContainer
                        else Color.Transparent
                    ) {
                        Text(
                            text = "${min} 分钟",
                            style = MaterialTheme.typography.bodyLarge,
                            color = if (min == currentTimerMin)
                                MaterialTheme.colorScheme.primary
                            else MaterialTheme.colorScheme.onSurface
                        )
                    }
                }
                Spacer(modifier = Modifier.height(24.dp))
            }
        }
    }
}
