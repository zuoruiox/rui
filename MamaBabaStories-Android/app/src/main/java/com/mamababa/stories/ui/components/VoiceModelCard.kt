package com.mamababa.stories.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.mamababa.stories.data.model.VoiceModel
import com.mamababa.stories.data.model.VoiceModelStatus
import com.mamababa.stories.ui.theme.*

/**
 * 声音模型卡片
 */
@Composable
fun VoiceModelCard(
    voice: VoiceModel,
    onClick: () -> Unit,
    onPlaySample: () -> Unit = {},
    onDelete: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
    selected: Boolean = false
) {
    val bgGradient = when (voice.ownerType) {
        "mom" -> listOf(PrimaryLight, Primary)
        "dad" -> listOf(TertiaryLight, Tertiary)
        "grandma" -> listOf(Secondary, SecondaryDark)
        "grandpa" -> listOf(Color(0xFF8D6E63), Color(0xFF5D4037))
        else -> listOf(PrimaryLight, TertiaryLight)
    }

    val borderColor = if (selected) MaterialTheme.colorScheme.primary
    else Color.Transparent

    Card(
        modifier = modifier
            .width(140.dp)
            .clickable(onClick = onClick, enabled = voice.status == VoiceModelStatus.READY),
        shape = RoundedCornerShape(20.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = if (selected) 6.dp else 2.dp),
        border = if (selected) androidx.compose.foundation.BorderStroke(2.dp, borderColor) else null,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // 头像区域
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(100.dp)
                    .background(Brush.linearGradient(bgGradient)),
                contentAlignment = Alignment.Center
            ) {
                // 头像图标
                Surface(
                    shape = CircleShape,
                    color = Color.White.copy(alpha = 0.3f),
                    modifier = Modifier.size(60.dp)
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(
                            imageVector = when (voice.ownerType) {
                                "mom" -> Icons.Filled.Face
                                "dad" -> Icons.Filled.Person
                                "grandma" -> Icons.Filled.Face
                                "grandpa" -> Icons.Filled.Person
                                else -> Icons.Filled.RecordVoiceOver
                            },
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(32.dp)
                        )
                    }
                }

                // 状态角标
                when (voice.status) {
                    VoiceModelStatus.TRAINING -> {
                        Surface(
                            modifier = Modifier
                                .align(Alignment.BottomCenter)
                                .fillMaxWidth(),
                            color = Color.Black.copy(alpha = 0.6f),
                            shape = RoundedCornerShape(topStart = 0.dp, topEnd = 0.dp)
                        ) {
                            Column(
                                modifier = Modifier.padding(vertical = 6.dp),
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                LinearProgressIndicator(
                                    progress = { voice.progress / 100f },
                                    modifier = Modifier
                                        .fillMaxWidth(0.7f)
                                        .height(4.dp)
                                        .clip(CircleShape),
                                    color = Secondary,
                                    trackColor = Color.White.copy(alpha = 0.3f),
                                )
                                Spacer(modifier = Modifier.height(2.dp))
                                Text(
                                    text = "训练中 ${voice.progress}%",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = Color.White
                                )
                            }
                        }
                    }
                    VoiceModelStatus.UPLOADING -> {
                        Surface(
                            modifier = Modifier.align(Alignment.BottomCenter).fillMaxWidth(),
                            color = Color.Black.copy(alpha = 0.6f),
                            shape = RoundedCornerShape(0.dp)
                        ) {
                            Text(
                                text = "上传中…",
                                style = MaterialTheme.typography.labelSmall,
                                color = Color.White,
                                modifier = Modifier.padding(6.dp)
                            )
                        }
                    }
                    VoiceModelStatus.FAILED -> {
                        Surface(
                            modifier = Modifier.align(Alignment.BottomCenter).fillMaxWidth(),
                            color = Error.copy(alpha = 0.9f),
                            shape = RoundedCornerShape(0.dp)
                        ) {
                            Text(
                                text = "训练失败",
                                style = MaterialTheme.typography.labelSmall,
                                color = Color.White,
                                modifier = Modifier.padding(6.dp)
                            )
                        }
                    }
                    else -> {
                        // 默认标识
                        if (voice.isDefault) {
                            Surface(
                                modifier = Modifier
                                    .align(Alignment.TopEnd)
                                    .padding(8.dp),
                                shape = RoundedCornerShape(6.dp),
                                color = Color.White.copy(alpha = 0.3f)
                            ) {
                                Text(
                                    text = "默认",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = Color.White,
                                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                )
                            }
                        }
                    }
                }
            }

            // 信息区域
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(12.dp)
            ) {
                Text(
                    text = voice.name,
                    style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold),
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 1
                )
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = voice.ownerLabel,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                if (voice.status == VoiceModelStatus.READY) {
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "${voice.durationSec / 60}分钟样本",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Row {
                            IconButton(
                                onClick = onPlaySample,
                                modifier = Modifier.size(28.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Filled.PlayCircle,
                                    contentDescription = "试听",
                                    tint = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.size(20.dp)
                                )
                            }
                            if (onDelete != null) {
                                IconButton(
                                    onClick = onDelete,
                                    modifier = Modifier.size(28.dp)
                                ) {
                                    Icon(
                                        imageVector = Icons.Filled.DeleteOutline,
                                        contentDescription = "删除",
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.size(18.dp)
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
