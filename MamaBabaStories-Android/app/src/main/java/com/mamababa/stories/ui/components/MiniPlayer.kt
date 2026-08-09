package com.mamababa.stories.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mamababa.stories.MamaBabaStoriesApp
import com.mamababa.stories.data.model.Story
import com.mamababa.stories.service.audio.PlaybackState
import com.mamababa.stories.service.audio.PlayerState
import com.mamababa.stories.ui.theme.*
import com.mamababa.stories.util.formatDuration
import kotlinx.coroutines.flow.StateFlow

/**
 * 迷你播放器（显示在底部导航上方）
 */
@Composable
fun MiniPlayer(
    onPlayerClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val app = remember { MamaBabaStoriesApp.getInstance() }
    val playerState by app.audioPlayerManager.state.collectAsState()
    val story = playerState.currentStory

    if (story == null && playerState.playbackState == PlaybackState.IDLE) {
        // 没有播放内容时不显示
        return
    }

    val currentStory = story ?: return

    val progress by animateFloatAsState(
        targetValue = playerState.progress,
        label = "miniProgress"
    )

    Surface(
        modifier = modifier
            .fillMaxWidth()
            .height(64.dp)
            .clickable(onClick = onPlayerClick),
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 4.dp
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // 进度条
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(2.dp),
                color = MaterialTheme.colorScheme.primary,
                trackColor = MaterialTheme.colorScheme.surfaceVariant,
            )

            Row(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // 封面
                val gradient = when (currentStory.categoryRaw) {
                    "fairy" -> WarmGradient
                    "fable" -> listOf(TertiaryLight, Tertiary)
                    "lullaby" -> listOf(Color(0xFF3A3A5C), Tertiary)
                    else -> SoftGradient
                }
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(Brush.linearGradient(gradient)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Filled.PlayArrow,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(24.dp)
                    )
                }

                Spacer(modifier = Modifier.width(12.dp))

                // 标题和声音
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = currentStory.title,
                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                        color = MaterialTheme.colorScheme.onSurface,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Text(
                        text = "${currentStory.voiceName} · ${playerState.currentPositionMs.formatDuration()}/${playerState.durationMs.formatDuration()}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1
                    )
                }

                // 播放/暂停按钮
                IconButton(
                    onClick = { app.audioPlayerManager.togglePlayPause() }
                ) {
                    Icon(
                        imageVector = if (playerState.isPlaying) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                        contentDescription = if (playerState.isPlaying) "暂停" else "播放",
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(32.dp)
                    )
                }
            }
        }
    }
}
