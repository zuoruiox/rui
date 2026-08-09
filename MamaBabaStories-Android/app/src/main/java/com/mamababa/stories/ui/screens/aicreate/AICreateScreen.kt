package com.mamababa.stories.ui.screens.aicreate

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
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
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.mamababa.stories.data.model.AIStoryRequest
import com.mamababa.stories.ui.theme.*
import com.mamababa.stories.viewmodel.AICreateViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AICreateScreen(
    onStoryCreated: () -> Unit,
    viewModel: AICreateViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val scrollState = rememberScrollState()

    // 生成完成后自动播放
    LaunchedEffect(uiState.generatedStoryObj) {
        if (uiState.generatedStoryObj != null && !uiState.isGenerating) {
            viewModel.playGeneratedStory()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(scrollState)
            .background(MaterialTheme.colorScheme.background)
    ) {
        // 顶部标题
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.linearGradient(
                        listOf(
                            Secondary.copy(alpha = 0.3f),
                            MaterialTheme.colorScheme.background
                        )
                    )
                )
                .padding(horizontal = 20.dp, vertical = 16.dp)
        ) {
            Column {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Filled.AutoAwesome,
                        contentDescription = null,
                        tint = SecondaryDark,
                        modifier = Modifier.size(28.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "AI 创作故事",
                        style = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.Bold),
                        color = MaterialTheme.colorScheme.onBackground
                    )
                }
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "告诉 AI 你想听什么故事，30秒生成专属故事",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        if (uiState.generatedStory != null && !uiState.isGenerating) {
            // 显示生成结果
            GeneratedStoryView(
                title = uiState.generatedStory!!.title,
                content = uiState.generatedStory!!.textContent,
                onPlay = {
                    viewModel.playGeneratedStory()
                    onStoryCreated()
                },
                onRegenerate = { viewModel.resetGeneration() }
            )
        } else {
            // 创作表单
            Column(modifier = Modifier.padding(horizontal = 16.dp)) {

                Spacer(modifier = Modifier.height(8.dp))

                // 主题选择
                SectionLabel(text = "故事主题")
                Spacer(modifier = Modifier.height(8.dp))
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    uiState.themes.forEach { theme ->
                        ThemeChip(
                            text = theme,
                            selected = uiState.selectedTheme == theme,
                            onClick = { viewModel.selectTheme(theme) }
                        )
                    }
                }

                Spacer(modifier = Modifier.height(20.dp))

                // 主角名字
                SectionLabel(text = "主角名字（可选）")
                Spacer(modifier = Modifier.height(8.dp))
                OutlinedTextField(
                    value = uiState.character,
                    onValueChange = { viewModel.setCharacter(it) },
                    modifier = Modifier.fillMaxWidth(),
                    placeholder = { Text("例如：小兔子豆豆") },
                    singleLine = true,
                    shape = RoundedCornerShape(14.dp),
                    leadingIcon = {
                        Icon(
                            imageVector = Icons.Filled.Pets,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    },
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = MaterialTheme.colorScheme.primary,
                        unfocusedBorderColor = MaterialTheme.colorScheme.outlineVariant
                    )
                )

                Spacer(modifier = Modifier.height(20.dp))

                // 代入孩子名字
                SectionLabel(text = "代入宝贝名字（可选）")
                Spacer(modifier = Modifier.height(8.dp))
                OutlinedTextField(
                    value = uiState.childName,
                    onValueChange = { viewModel.setChildName(it) },
                    modifier = Modifier.fillMaxWidth(),
                    placeholder = { Text("让主角叫宝贝的名字") },
                    singleLine = true,
                    shape = RoundedCornerShape(14.dp),
                    leadingIcon = {
                        Icon(
                            imageVector = Icons.Filled.ChildCare,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    },
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = MaterialTheme.colorScheme.primary,
                        unfocusedBorderColor = MaterialTheme.colorScheme.outlineVariant
                    )
                )

                Spacer(modifier = Modifier.height(20.dp))

                // 适合年龄
                SectionLabel(text = "适合年龄")
                Spacer(modifier = Modifier.height(8.dp))
                AgeSelector(
                    currentMin = uiState.ageMin,
                    currentMax = uiState.ageMax,
                    onAgeSelected = { min, max -> viewModel.setAgeRange(min, max) }
                )

                Spacer(modifier = Modifier.height(20.dp))

                // 故事风格
                SectionLabel(text = "故事风格")
                Spacer(modifier = Modifier.height(8.dp))
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    uiState.styles.forEach { (value, label) ->
                        ThemeChip(
                            text = label,
                            selected = uiState.selectedStyle == value,
                            onClick = { viewModel.selectStyle(value) }
                        )
                    }
                }

                Spacer(modifier = Modifier.height(20.dp))

                // 故事长度
                SectionLabel(text = "故事长度")
                Spacer(modifier = Modifier.height(8.dp))
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    uiState.lengths.forEach { (value, label) ->
                        ThemeChip(
                            text = label,
                            selected = uiState.selectedLength == value,
                            onClick = { viewModel.selectLength(value) }
                        )
                    }
                }

                Spacer(modifier = Modifier.height(20.dp))

                // 选择声音
                if (uiState.voices.isNotEmpty()) {
                    SectionLabel(text = "讲述声音")
                    Spacer(modifier = Modifier.height(8.dp))
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        uiState.voices.forEach { voice ->
                            ThemeChip(
                                text = voice.name,
                                selected = uiState.selectedVoiceId == voice.id,
                                onClick = { viewModel.selectVoice(voice.id) }
                            )
                        }
                    }
                    Spacer(modifier = Modifier.height(20.dp))
                }

                // 生成按钮
                Button(
                    onClick = { viewModel.generate() },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp),
                    shape = RoundedCornerShape(28.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Secondary,
                        contentColor = OnSecondary
                    ),
                    enabled = uiState.canGenerate && !uiState.isGenerating
                ) {
                    if (uiState.isGenerating) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(20.dp),
                            color = OnSecondary,
                            strokeWidth = 2.dp
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("AI 创作中…")
                    } else {
                        Icon(
                            imageVector = Icons.Filled.AutoAwesome,
                            contentDescription = null,
                            modifier = Modifier.size(20.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "生成故事",
                            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold)
                        )
                    }
                }

                Spacer(modifier = Modifier.height(100.dp))
            }
        }

        // 生成中遮罩
        if (uiState.isGenerating) {
            LinearProgressIndicator(
                progress = { uiState.generationProgress },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(4.dp)
                    .padding(horizontal = 16.dp),
                color = Secondary,
                trackColor = MaterialTheme.colorScheme.surfaceVariant
            )
        }
    }
}

@Composable
private fun SectionLabel(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold),
        color = MaterialTheme.colorScheme.onBackground
    )
}

@Composable
private fun ThemeChip(
    text: String,
    selected: Boolean,
    onClick: () -> Unit
) {
    Surface(
        modifier = Modifier
            .height(40.dp)
            .clip(RoundedCornerShape(20.dp))
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(20.dp),
        color = if (selected) MaterialTheme.colorScheme.primary
        else MaterialTheme.colorScheme.surfaceVariant,
        tonalElevation = if (selected) 0.dp else 1.dp
    ) {
        Box(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = text,
                style = MaterialTheme.typography.labelLarge,
                color = if (selected) MaterialTheme.colorScheme.onPrimary
                else MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun AgeSelector(
    currentMin: Int,
    currentMax: Int,
    onAgeSelected: (Int, Int) -> Unit
) {
    val ranges = listOf(
        (0 to 2) to "0-2岁",
        (3 to 4) to "3-4岁",
        (5 to 6) to "5-6岁",
        (7 to 9) to "7-9岁",
        (10 to 12) to "10岁+"
    )
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        ranges.forEach { (range, label) ->
            val (min, max) = range
            val selected = currentMin == min && currentMax == max
            Surface(
                modifier = Modifier
                    .weight(1f)
                    .height(44.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .clickable { onAgeSelected(min, max) },
                shape = RoundedCornerShape(12.dp),
                color = if (selected) MaterialTheme.colorScheme.primary
                else MaterialTheme.colorScheme.surfaceVariant
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Text(
                        text = label,
                        style = MaterialTheme.typography.labelLarge,
                        color = if (selected) MaterialTheme.colorScheme.onPrimary
                        else MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

@Composable
private fun GeneratedStoryView(
    title: String,
    content: String,
    onPlay: () -> Unit,
    onRegenerate: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp)
    ) {
        // 成功标识
        Row(verticalAlignment = Alignment.CenterVertically) {
            Surface(
                shape = CircleShape,
                color = Success.copy(alpha = 0.2f),
                modifier = Modifier.size(36.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = Icons.Filled.Check,
                        contentDescription = null,
                        tint = Success,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
            Spacer(modifier = Modifier.width(12.dp))
            Text(
                text = "故事创作完成！",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = Success
            )
        }

        Spacer(modifier = Modifier.height(16.dp))

        // 故事卡片
        Surface(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(20.dp),
            color = MaterialTheme.colorScheme.surface,
            tonalElevation = 2.dp
        ) {
            Column(modifier = Modifier.padding(20.dp)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold),
                    color = MaterialTheme.colorScheme.onBackground
                )
                Spacer(modifier = Modifier.height(12.dp))
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = content,
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurface,
                    lineHeight = MaterialTheme.typography.bodyLarge.lineHeight * 1.6f
                )
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // 操作按钮
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            OutlinedButton(
                onClick = onRegenerate,
                modifier = Modifier
                    .weight(1f)
                    .height(52.dp),
                shape = RoundedCornerShape(26.dp)
            ) {
                Icon(
                    imageVector = Icons.Filled.Refresh,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text("重新创作")
            }
            Button(
                onClick = onPlay,
                modifier = Modifier
                    .weight(1f)
                    .height(52.dp),
                shape = RoundedCornerShape(26.dp),
                colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
            ) {
                Icon(
                    imageVector = Icons.Filled.PlayArrow,
                    contentDescription = null,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = "播放故事",
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold)
                )
            }
        }

        Spacer(modifier = Modifier.height(100.dp))
    }
}
