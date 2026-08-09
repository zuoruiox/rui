package com.mamababa.stories.ui.screens.voice

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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mamababa.stories.data.model.VoiceModel
import com.mamababa.stories.data.model.VoiceModelStatus
import com.mamababa.stories.ui.components.VoiceModelCard
import com.mamababa.stories.ui.theme.*
import com.mamababa.stories.viewmodel.VoiceCloneViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VoiceCloneScreen(
    onBack: () -> Unit,
    onStartRecording: (String) -> Unit
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val viewModel = remember { VoiceCloneViewModel(context) }
    val state by viewModel.uiState.collectAsState()
    val scrollState = rememberScrollState()

    // 错误提示
    state.error?.let { error ->
        LaunchedEffect(error) {
            viewModel.clearError()
        }
    }

    // 完成提示
    state.completedMessage?.let { msg ->
        LaunchedEffect(msg) {
            viewModel.clearCompletedMessage()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "声音克隆",
                        style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold)
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.Filled.ArrowBack,
                            contentDescription = "返回"
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(scrollState)
                .background(MaterialTheme.colorScheme.background)
        ) {
            // 顶部介绍卡片
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                shape = RoundedCornerShape(24.dp),
                color = Color.Transparent
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            Brush.linearGradient(WarmGradient),
                            RoundedCornerShape(24.dp)
                        )
                        .padding(24.dp)
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(
                            imageVector = Icons.Filled.Mic,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(48.dp)
                        )
                        Spacer(modifier = Modifier.height(12.dp))
                        Text(
                            text = "用爸爸妈妈的声音讲故事",
                            style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                            color = Color.White,
                            textAlign = TextAlign.Center
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "只需录制 3 分钟，AI 就能克隆你的声音，\n让宝贝随时听到爸爸妈妈讲的故事",
                            style = MaterialTheme.typography.bodyMedium,
                            color = Color.White.copy(alpha = 0.9f),
                            textAlign = TextAlign.Center
                        )
                    }
                }
            }

            // 录制提示
            Text(
                text = "录制小贴士",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                modifier = Modifier.padding(horizontal = 16.dp)
            )
            Spacer(modifier = Modifier.height(8.dp))

            val tips = listOf(
                Triple(Icons.Filled.Mic, "找一个安静的房间", "避免背景噪音"),
                Triple(Icons.Filled.RecordVoiceOver, "用自然的语速朗读", "像平时给宝贝讲故事一样"),
                Triple(Icons.Filled.SurroundSound, "距离麦克风 15-20 厘米", "不要太近也不要太远")
            )
            tips.forEach { (icon, title, desc) ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Surface(
                        shape = CircleShape,
                        color = MaterialTheme.colorScheme.primaryContainer,
                        modifier = Modifier.size(36.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(
                                imageVector = icon,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                    }
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Text(
                            text = title,
                            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                            color = MaterialTheme.colorScheme.onBackground
                        )
                        Text(
                            text = desc,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // 选择声音类型
            Text(
                text = "选择声音类型",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                modifier = Modifier.padding(horizontal = 16.dp)
            )
            Spacer(modifier = Modifier.height(12.dp))

            val voiceTypes = listOf(
                "mom" to "妈妈",
                "dad" to "爸爸",
                "grandma" to "奶奶/外婆",
                "grandpa" to "爷爷/外公",
                "custom" to "自定义"
            )
            LazyRow(
                contentPadding = PaddingValues(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(voiceTypes) { (type, label) ->
                    FilterChip(
                        selected = state.selectedVoiceType == type,
                        onClick = { viewModel.selectVoiceType(type) },
                        label = { Text(label) },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = MaterialTheme.colorScheme.primary,
                            selectedLabelColor = MaterialTheme.colorScheme.onPrimary
                        )
                    )
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // 开始录制按钮
            Button(
                onClick = {
                    if (!state.isRecording && !state.isTraining && !state.isUploading) {
                        onStartRecording("")
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .height(56.dp),
                shape = RoundedCornerShape(28.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.primary
                ),
                enabled = !state.isTraining && !state.isUploading
            ) {
                when {
                    state.isUploading -> {
                        CircularProgressIndicator(
                            modifier = Modifier.size(20.dp),
                            color = MaterialTheme.colorScheme.onPrimary,
                            strokeWidth = 2.dp
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("上传中…")
                    }
                    state.isTraining -> {
                        CircularProgressIndicator(
                            modifier = Modifier.size(20.dp),
                            color = MaterialTheme.colorScheme.onPrimary,
                            strokeWidth = 2.dp
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("训练中 ${state.trainingProgress}%")
                    }
                    else -> {
                        Icon(
                            imageVector = Icons.Filled.FiberManualRecord,
                            contentDescription = null,
                            modifier = Modifier.size(20.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "开始录制",
                            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold)
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // 已有声音模型
            if (state.voices.isNotEmpty()) {
                Text(
                    text = "我的声音模型",
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
                Spacer(modifier = Modifier.height(12.dp))
                LazyRow(
                    contentPadding = PaddingValues(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(state.voices) { voice ->
                        VoiceModelCard(
                            voice = voice,
                            onClick = { /* 选择为默认 */ },
                            onPlaySample = { /* 试听 */ },
                            onDelete = { viewModel.deleteVoice(voice) }
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(100.dp))
        }
    }
}
