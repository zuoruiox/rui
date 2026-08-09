package com.mamababa.stories.ui.screens.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
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
import com.mamababa.stories.data.model.Story
import com.mamababa.stories.data.model.VoiceModel
import com.mamababa.stories.ui.components.StoryCard
import com.mamababa.stories.ui.components.VoiceModelCard
import com.mamababa.stories.ui.theme.*
import com.mamababa.stories.viewmodel.HomeViewModel
import java.util.Calendar

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    onStoryClick: (Story) -> Unit,
    onVoiceCloneClick: () -> Unit,
    onSeeAllStories: () -> Unit,
    viewModel: HomeViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val scrollState = rememberScrollState()

    // 根据时间生成问候语
    val greeting = remember {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        when (hour) {
            in 5..11 -> "早上好"
            in 12..13 -> "中午好"
            in 14..17 -> "下午好"
            else -> "晚上好"
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(scrollState)
            .background(MaterialTheme.colorScheme.background)
    ) {
        // 顶部问候区域
        HomeHeader(
            greeting = greeting,
            userName = uiState.user?.nickname ?: "爸爸妈妈",
            onVoiceCloneClick = onVoiceCloneClick
        )

        Spacer(modifier = Modifier.height(16.dp))

        // 快速创作入口
        QuickCreateCard(onClick = onSeeAllStories)

        Spacer(modifier = Modifier.height(24.dp))

        // 我的声音
        if (uiState.voiceModels.isNotEmpty()) {
            SectionHeader(
                title = "我的声音",
                action = "管理",
                onActionClick = onVoiceCloneClick
            )
            Spacer(modifier = Modifier.height(12.dp))
            LazyRow(
                contentPadding = PaddingValues(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                item {
                    AddVoiceCard(onClick = onVoiceCloneClick)
                }
                items(uiState.voiceModels.take(5)) { voice ->
                    VoiceModelCard(
                        voice = voice,
                        onClick = { /* 选择声音 */ },
                        onPlaySample = { /* 试听 */ }
                    )
                }
            }
            Spacer(modifier = Modifier.height(24.dp))
        } else {
            // 没有声音模型时显示引导
            VoiceClonePrompt(onClick = onVoiceCloneClick)
            Spacer(modifier = Modifier.height(24.dp))
        }

        // 今日推荐
        SectionHeader(
            title = "今日推荐",
            action = "更多",
            onActionClick = onSeeAllStories
        )
        Spacer(modifier = Modifier.height(12.dp))
        if (uiState.isLoading && uiState.recommendStories.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(200.dp),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
            }
        } else {
            LazyRow(
                contentPadding = PaddingValues(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(uiState.recommendStories) { story ->
                    StoryCard(
                        story = story,
                        onClick = {
                            viewModel.playStory(story)
                            onStoryClick(story)
                        },
                        large = true
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // 最近播放
        if (uiState.recentStories.isNotEmpty()) {
            SectionHeader(title = "最近播放")
            Spacer(modifier = Modifier.height(12.dp))
            LazyRow(
                contentPadding = PaddingValues(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(uiState.recentStories) { story ->
                    StoryCard(
                        story = story,
                        onClick = {
                            viewModel.playStory(story)
                            onStoryClick(story)
                        }
                    )
                }
            }
            Spacer(modifier = Modifier.height(100.dp)) // 为 mini player 留空间
        } else {
            Spacer(modifier = Modifier.height(100.dp))
        }
    }
}

@Composable
private fun HomeHeader(
    greeting: String,
    userName: String,
    onVoiceCloneClick: () -> Unit
) {
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
            .padding(horizontal = 20.dp, vertical = 16.dp)
    ) {
        Column {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "$greeting，$userName 👋",
                        style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold),
                        color = MaterialTheme.colorScheme.onBackground
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "今天给宝贝讲什么故事呢？",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                // 头像
                Surface(
                    shape = CircleShape,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(44.dp)
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(
                            imageVector = Icons.Filled.Face,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(24.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun QuickCreateCard(onClick: () -> Unit) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(20.dp),
        color = MaterialTheme.colorScheme.primary,
        tonalElevation = 4.dp
    ) {
        Row(
            modifier = Modifier.padding(20.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Surface(
                shape = CircleShape,
                color = Color.White.copy(alpha = 0.25f),
                modifier = Modifier.size(52.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = Icons.Filled.AutoAwesome,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(28.dp)
                    )
                }
            }
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "AI 快速创作",
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                    color = Color.White
                )
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = "输入主题，30秒生成专属故事",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White.copy(alpha = 0.9f)
                )
            }
            Icon(
                imageVector = Icons.Filled.ChevronRight,
                contentDescription = null,
                tint = Color.White
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
            style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
            color = MaterialTheme.colorScheme.onBackground
        )
        if (action != null && onActionClick != null) {
            TextButton(onClick = onActionClick) {
                Text(text = action, color = MaterialTheme.colorScheme.primary)
                Icon(
                    imageVector = Icons.Filled.ChevronRight,
                    contentDescription = null,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
    }
}

@Composable
private fun AddVoiceCard(onClick: () -> Unit) {
    Surface(
        modifier = Modifier
            .width(140.dp)
            .height(180.dp)
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(20.dp),
        color = MaterialTheme.colorScheme.surfaceVariant
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Surface(
                shape = CircleShape,
                color = MaterialTheme.colorScheme.primary.copy(alpha = 0.15f),
                modifier = Modifier.size(52.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = Icons.Filled.Add,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(28.dp)
                    )
                }
            }
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "克隆新声音",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.primary
            )
        }
    }
}

@Composable
private fun VoiceClonePrompt(onClick: () -> Unit) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(20.dp),
        color = Secondary.copy(alpha = 0.2f)
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Filled.Mic,
                contentDescription = null,
                tint = SecondaryDark,
                modifier = Modifier.size(32.dp)
            )
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "录制你的声音",
                    style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold),
                    color = OnSecondary
                )
                Text(
                    text = "3分钟，让故事用爸爸妈妈的声音讲述",
                    style = MaterialTheme.typography.bodySmall,
                    color = OnSecondary.copy(alpha = 0.8f)
                )
            }
            Icon(
                imageVector = Icons.Filled.ChevronRight,
                contentDescription = null,
                tint = OnSecondary
            )
        }
    }
}
