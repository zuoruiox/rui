package com.mamababa.stories.ui.screens.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.mamababa.stories.data.model.TTSConfig
import com.mamababa.stories.data.model.User
import com.mamababa.stories.ui.components.VoiceModelCard
import com.mamababa.stories.ui.theme.*
import com.mamababa.stories.viewmodel.ProfileViewModel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(
    onVoiceCloneClick: () -> Unit,
    viewModel: ProfileViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val user = uiState.user ?: User.PREVIEW

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
        contentPadding = PaddingValues(bottom = 100.dp)
    ) {
        // 用户信息头部
        item {
            ProfileHeader(user = user)
        }

        // 会员卡片
        item {
            Spacer(modifier = Modifier.height(16.dp))
            MembershipCard(user = user)
        }

        // 我的声音
        item {
            Spacer(modifier = Modifier.height(20.dp))
            SectionHeader(
                title = "我的声音",
                action = if (uiState.voices.size < 5) "添加" else null,
                onActionClick = onVoiceCloneClick
            )
        }

        if (uiState.voices.isEmpty()) {
            item {
                EmptyVoiceCard(onClick = onVoiceCloneClick)
            }
        } else {
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    uiState.voices.take(3).forEach { voice ->
                        Box(modifier = Modifier.weight(1f)) {
                            VoiceModelCard(
                                voice = voice,
                                onClick = {},
                                modifier = Modifier.fillMaxWidth()
                            )
                        }
                    }
                }
            }
        }

        // 设置项
        item {
            Spacer(modifier = Modifier.height(24.dp))
            Text(
                text = "设置",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                modifier = Modifier.padding(horizontal = 16.dp)
            )
            Spacer(modifier = Modifier.height(8.dp))
        }

        item {
            SettingsCard(
                autoPlayNext = uiState.autoPlayNext,
                playbackSpeed = uiState.playbackSpeed,
                onAutoPlayNextChange = { viewModel.setAutoPlayNext(it) },
                onSpeedClick = { viewModel.showSpeedDialog(true) }
            )
        }

        // 其他菜单项
        item {
            Spacer(modifier = Modifier.height(16.dp))
            MenuCard()
        }

        // 退出登录
        item {
            Spacer(modifier = Modifier.height(24.dp))
            OutlinedButton(
                onClick = { viewModel.showLogoutDialog(true) },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .height(48.dp),
                shape = RoundedCornerShape(24.dp),
                colors = ButtonDefaults.outlinedButtonColors(
                    contentColor = MaterialTheme.colorScheme.error
                )
            ) {
                Text("退出登录")
            }
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "版本 1.0.0",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.fillMaxWidth(),
                textAlign = androidx.compose.ui.text.style.TextAlign.Center
            )
        }
    }

    // 速度选择对话框
    if (uiState.showSpeedDialog) {
        SpeedDialog(
            currentSpeed = uiState.playbackSpeed,
            onSpeedSelected = { viewModel.setPlaybackSpeed(it) },
            onDismiss = { viewModel.showSpeedDialog(false) }
        )
    }

    // 退出登录确认
    if (uiState.showLogoutDialog) {
        AlertDialog(
            onDismissRequest = { viewModel.showLogoutDialog(false) },
            title = { Text("退出登录") },
            text = { Text("确定要退出登录吗？") },
            confirmButton = {
                TextButton(onClick = { viewModel.logout() }) {
                    Text("确定", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { viewModel.showLogoutDialog(false) }) {
                    Text("取消")
                }
            }
        )
    }
}

@Composable
private fun ProfileHeader(user: User) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                Brush.verticalGradient(
                    listOf(
                        MaterialTheme.colorScheme.primaryContainer,
                        MaterialTheme.colorScheme.background
                    )
                )
            )
            .padding(20.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically
        ) {
            // 头像
            Surface(
                shape = CircleShape,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(64.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = Icons.Filled.Face,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(36.dp)
                    )
                }
            }
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = user.nickname,
                    style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold),
                    color = MaterialTheme.colorScheme.onBackground
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = user.phone.ifEmpty { "点击登录" },
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            IconButton(onClick = { /* 编辑资料 */ }) {
                Icon(
                    imageVector = Icons.Filled.Settings,
                    contentDescription = "设置",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun MembershipCard(user: User) {
    val isVip = user.isVip
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clickable { /* 开通会员 */ },
        shape = RoundedCornerShape(20.dp),
        color = if (isVip) Secondary
        else MaterialTheme.colorScheme.surfaceVariant
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Surface(
                shape = CircleShape,
                color = (if (isVip) Color.White else Primary).copy(alpha = 0.25f),
                modifier = Modifier.size(44.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = Icons.Filled.WorkspacePremium,
                        contentDescription = null,
                        tint = if (isVip) Color.White else Primary,
                        modifier = Modifier.size(24.dp)
                    )
                }
            }
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = if (isVip) "VIP 会员" else "开通会员",
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                    color = if (isVip) OnSecondary else MaterialTheme.colorScheme.onBackground
                )
                Text(
                    text = if (isVip) {
                        val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.CHINA)
                        "有效期至 ${sdf.format(Date(user.vipExpireAt))}"
                    } else {
                        "无限故事 · 专属声音 · 无广告"
                    },
                    style = MaterialTheme.typography.bodySmall,
                    color = if (isVip) OnSecondary.copy(alpha = 0.85f)
                    else MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Icon(
                imageVector = Icons.Filled.ChevronRight,
                contentDescription = null,
                tint = if (isVip) OnSecondary else MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun SectionHeader(
    title: String,
    action: String? = null,
    onActionClick: (() -> Unit)? = null
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
            color = MaterialTheme.colorScheme.onBackground
        )
        if (action != null && onActionClick != null) {
            TextButton(onClick = onActionClick) {
                Text(text = action, color = MaterialTheme.colorScheme.primary)
                Icon(
                    imageVector = Icons.Filled.Add,
                    contentDescription = null,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
    }
}

@Composable
private fun EmptyVoiceCard(onClick: () -> Unit) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceVariant
    ) {
        Row(
            modifier = Modifier.padding(20.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Filled.Mic,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(32.dp)
            )
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "还没有声音模型",
                    style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Medium),
                    color = MaterialTheme.colorScheme.onBackground
                )
                Text(
                    text = "录制 3 分钟，克隆你的声音",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Icon(
                imageVector = Icons.Filled.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun SettingsCard(
    autoPlayNext: Boolean,
    playbackSpeed: Float,
    onAutoPlayNextChange: (Boolean) -> Unit,
    onSpeedClick: () -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surface
    ) {
        Column {
            // 自动连播
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Filled.PlaylistPlay,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.width(16.dp))
                Text(
                    text = "自动连播",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.weight(1f)
                )
                Switch(
                    checked = autoPlayNext,
                    onCheckedChange = onAutoPlayNextChange,
                    colors = SwitchDefaults.colors(
                        checkedThumbColor = MaterialTheme.colorScheme.primary,
                        checkedTrackColor = MaterialTheme.colorScheme.primaryContainer
                    )
                )
            }
            HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
            // 播放速度
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(onClick = onSpeedClick)
                    .padding(horizontal = 16.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Filled.Speed,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.width(16.dp))
                Text(
                    text = "播放速度",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.weight(1f)
                )
                Text(
                    text = "${playbackSpeed}x",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.primary
                )
                Spacer(modifier = Modifier.width(4.dp))
                Icon(
                    imageVector = Icons.Filled.ChevronRight,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(18.dp)
                )
            }
        }
    }
}

@Composable
private fun MenuCard() {
    val items = listOf(
        Triple(Icons.Filled.Download, "离线下载", null),
        Triple(Icons.Filled.Favorite, "我的收藏", null),
        Triple(Icons.Filled.History, "播放历史", null),
        Triple(Icons.Filled.Feedback, "意见反馈", null),
        Triple(Icons.Filled.Info, "关于我们", "v1.0.0")
    )
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surface
    ) {
        Column {
            items.forEachIndexed { index, (icon, label, trailing) ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { }
                        .padding(horizontal = 16.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.width(16.dp))
                    Text(
                        text = label,
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.weight(1f)
                    )
                    if (trailing != null) {
                        Text(
                            text = trailing,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                    }
                    Icon(
                        imageVector = Icons.Filled.ChevronRight,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(18.dp)
                    )
                }
                if (index < items.size - 1) {
                    HorizontalDivider(modifier = Modifier.padding(start = 56.dp, end = 16.dp))
                }
            }
        }
    }
}

@Composable
private fun SpeedDialog(
    currentSpeed: Float,
    onSpeedSelected: (Float) -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("播放速度") },
        text = {
            Column {
                TTSConfig.SPEED_OPTIONS.forEach { speed ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onSpeedSelected(speed) }
                            .padding(vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        RadioButton(
                            selected = speed == currentSpeed,
                            onClick = { onSpeedSelected(speed) },
                            colors = RadioButtonDefaults.colors(
                                selectedColor = MaterialTheme.colorScheme.primary
                            )
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "${speed}x",
                            style = MaterialTheme.typography.bodyLarge
                        )
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text("关闭") }
        }
    )
}
