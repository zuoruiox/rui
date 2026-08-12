//
//  AICreateView.swift
//  MamaBabaStories
//
//  AI 创作故事视图
//

import SwiftUI

struct AICreateView: View {
    @EnvironmentObject var aiVM: AICreateViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @State private var showingResult = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // 顶部标题
                    headerSection
                        .padding(.horizontal, Layout.horizontalPadding)

                    // 主题选择
                    themeSection
                        .padding(.horizontal, Layout.horizontalPadding)

                    // 角色输入
                    characterSection
                        .padding(.horizontal, Layout.horizontalPadding)

                    // 故事风格
                    styleSection
                        .padding(.horizontal, Layout.horizontalPadding)

                    // 适合年龄
                    ageSection
                        .padding(.horizontal, Layout.horizontalPadding)

                    // 故事长度
                    lengthSection
                        .padding(.horizontal, Layout.horizontalPadding)

                    // 选择声音
                    voiceSection
                        .padding(.horizontal, Layout.horizontalPadding)

                    // 自定义要求
                    customPromptSection
                        .padding(.horizontal, Layout.horizontalPadding)

                    // 生成按钮
                    generateButton
                        .padding(.horizontal, Layout.horizontalPadding)
                        .padding(.bottom, playerVM.isMiniPlayerVisible ? 80 : 30)
                }
                .padding(.top, 8)
            }
            .background(AppColors.background)
            .navigationTitle("AI创作")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingResult) {
                GeneratedStoryView()
            }
            .onChange(of: aiVM.showingStoryResult) { _, newValue in
                showingResult = newValue
            }
            .overlay {
                if aiVM.isGenerating {
                    generatingOverlay
                }
            }
            .alert("错误", isPresented: $aiVM.showError) {
                Button("好的", role: .cancel) {}
            } message: {
                Text(aiVM.errorMessage ?? "未知错误")
            }
            .task {
                await aiVM.loadData()
            }
            .onAppear {
                Task { await aiVM.loadData() }
            }
        }
    }

    // MARK: - 头部
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("✨")
                    .font(.system(size: 32))
                Text("AI故事创作")
                    .font(AppFonts.title(size: 26))
                    .foregroundColor(AppColors.textPrimary)
            }
            Text("选择主题和风格，AI为宝贝创作专属故事")
                .font(AppFonts.body())
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 主题选择
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择主题")
                .font(AppFonts.headline(size: 18))
                .foregroundColor(AppColors.textPrimary)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 70), spacing: 10)
            ], spacing: 10) {
                ForEach(StoryTheme.allCases) { theme in
                    ThemeSelectCard(theme: theme, isSelected: aiVM.selectedTheme == theme) {
                        aiVM.selectedTheme = theme
                    }
                }
            }
        }
    }

    // MARK: - 角色输入
    private var characterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("主角名字（可选）")
                .font(AppFonts.headline(size: 18))
                .foregroundColor(AppColors.textPrimary)

            TextField("例如：小兔子、小恐龙、超级英雄...", text: $aiVM.characterName)
                .font(AppFonts.body())
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.surface)
                        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
                )

            Toggle(isOn: $aiVM.includeChildName) {
                Text("加入宝贝名字")
                    .font(AppFonts.body(size: 14))
                    .foregroundColor(AppColors.textSecondary)
            }
            .tint(AppColors.softOrange)
        }
    }

    // MARK: - 风格选择
    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("故事风格")
                .font(AppFonts.headline(size: 18))
                .foregroundColor(AppColors.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(StoryStyle.allCases) { style in
                        TagButton(title: style.rawValue, icon: nil, isSelected: aiVM.selectedStyle == style) {
                            aiVM.selectedStyle = style
                        }
                    }
                }
            }
        }
    }

    // MARK: - 年龄选择
    private var ageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("适合年龄")
                .font(AppFonts.headline(size: 18))
                .foregroundColor(AppColors.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(AgeGroup.allCases) { age in
                        TagButton(title: age.rawValue, icon: nil, isSelected: aiVM.selectedAgeGroup == age) {
                            aiVM.selectedAgeGroup = age
                        }
                    }
                }
            }
        }
    }

    // MARK: - 长度选择
    private var lengthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("故事长度")
                    .font(AppFonts.headline(size: 18))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text(aiVM.estimatedDuration)
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textTertiary)
            }

            ForEach(WordCountOption.allCases) { option in
                lengthOptionRow(option: option)
            }
        }
    }

    private func lengthOptionRow(option: WordCountOption) -> some View {
        let isSelected = aiVM.selectedWordCount == option
        let bgColor = isSelected ? AppColors.softOrange.opacity(0.1) : AppColors.surface
        let strokeColor = isSelected ? AppColors.softOrange : Color.clear
        let fontWeight: Font.Weight = isSelected ? .semibold : .regular

        return Button(action: {
            aiVM.selectedWordCount = option
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.displayName)
                        .font(AppFonts.body(size: 15, weight: fontWeight))
                        .foregroundColor(AppColors.textPrimary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.softOrange)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(bgColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(strokeColor, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 声音选择
    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("讲述声音")
                .font(AppFonts.headline(size: 18))
                .foregroundColor(AppColors.textPrimary)

            if aiVM.availableVoiceModels.isEmpty {
                HStack {
                    Image(systemName: "mic.slash")
                        .foregroundColor(AppColors.textTertiary)
                    Text("还没有可用的声音，请先在「声音」页面录制")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(AppColors.surface)
                .cornerRadius(12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(aiVM.availableVoiceModels.filter { $0.statusEnum == .ready }) { model in
                            VoiceModelCard(voiceModel: model, isSelected: aiVM.selectedVoiceModel?.id == model.id) {
                                aiVM.selectedVoiceModel = model
                            } onPlay: {
                                // 试听
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 自定义要求
    private var customPromptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("额外要求（可选）")
                .font(AppFonts.headline(size: 18))
                .foregroundColor(AppColors.textPrimary)

            ZStack(alignment: .topLeading) {
                if aiVM.customPrompt.isEmpty {
                    Text("例如：加入教育意义、有惊喜结局、提到某个特定场景...")
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.textTertiary)
                        .padding(16)
                }

                TextEditor(text: $aiVM.customPrompt)
                    .font(AppFonts.body())
                    .frame(minHeight: 80)
                    .padding(12)
                    .scrollContentBackground(.hidden)
                    .background(AppColors.surface)
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - 生成按钮
    private var generateButton: some View {
        PrimaryButton("生成故事", icon: "sparkles", isDisabled: !aiVM.canGenerate, isLoading: aiVM.isGenerating, height: Layout.largeButtonHeight) {
            aiVM.generateStory()
        }
    }

    // MARK: - 生成中遮罩
    private var generatingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(AppColors.softOrange.opacity(0.3), lineWidth: 3)
                            .frame(width: 60 + CGFloat(i) * 20, height: 60 + CGFloat(i) * 20)
                            .scaleEffect(aiVM.isGenerating ? 1.2 : 0.8)
                            .opacity(aiVM.isGenerating ? 0 : 0.5)
                            .animation(.easeInOut(duration: 1.5).repeatForever().delay(Double(i) * 0.3), value: aiVM.isGenerating)
                    }
                    Image(systemName: "sparkles")
                        .font(.system(size: 30))
                        .foregroundColor(AppColors.softOrange)
                }

                VStack(spacing: 8) {
                    Text(aiVM.generationStage)
                        .font(AppFonts.headline(size: 18))
                        .foregroundColor(.white)
                    ProgressView(value: aiVM.generationProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: AppColors.softOrange))
                        .frame(width: 200)
                }
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
        }
    }
}

// MARK: - 主题选择卡片
struct ThemeSelectCard: View {
    let theme: StoryTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? AppColors.softOrange : AppColors.softOrange.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Text(theme.icon)
                        .font(.system(size: 24))
                }
                Text(theme.rawValue)
                    .font(AppFonts.caption(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? AppColors.softOrange : AppColors.textSecondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 生成结果视图
struct GeneratedStoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var aiVM: AICreateViewModel
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    if let story = aiVM.generatedStory {
                        // 封面
                        ZStack {
                            RoundedRectangle(cornerRadius: Layout.largeCornerRadius)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [AppColors.warmYellow, AppColors.softOrange]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 200)

                            Text(story.coverEmoji)
                                .font(.system(size: 80))
                        }
                        .padding(.horizontal, Layout.horizontalPadding)
                        .padding(.top, 10)

                        // 标题
                        VStack(spacing: 8) {
                            Text(story.title)
                                .font(AppFonts.title(size: 24))
                                .foregroundColor(AppColors.textPrimary)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 12) {
                                Label("\(story.wordCount)字", systemImage: "doc.text")
                                Label(String(format: "约%.0f分钟", max(1, story.suggestedDuration / 60)), systemImage: "clock")
                                if let voice = aiVM.selectedVoiceModel {
                                    Label(voice.name, systemImage: "mic.fill")
                                }
                            }
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.horizontal, Layout.horizontalPadding)

                        // 故事内容
                        VStack(alignment: .leading, spacing: 8) {
                            Text(aiVM.editedContent)
                                .font(AppFonts.body(size: 16))
                                .foregroundColor(AppColors.textPrimary)
                                .lineSpacing(8)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                                .fill(AppColors.surface)
                                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                        )
                        .padding(.horizontal, Layout.horizontalPadding)

                        // 标签
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(story.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(AppFonts.caption(size: 12))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(AppColors.surfaceVariant)
                                        .foregroundColor(AppColors.textSecondary)
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal, Layout.horizontalPadding)
                        }

                        // 操作按钮
                        VStack(spacing: 12) {
                            PrimaryButton("播放故事", icon: "play.fill", height: Layout.largeButtonHeight) {
                                if let savedStory = aiVM.saveStory() {
                                    playerVM.play(story: savedStory)
                                    dismiss()
                                }
                            }

                            HStack(spacing: 12) {
                                SecondaryButton("重新生成", icon: "arrow.clockwise") {
                                    aiVM.regenerateStory()
                                }
                                SecondaryButton("编辑修改", icon: "pencil") {
                                    aiVM.isEditing = true
                                }
                                SecondaryButton("保存", icon: "bookmark") {
                                    _ = aiVM.saveStory()
                                    dismiss()
                                }
                            }
                        }
                        .padding(.horizontal, Layout.horizontalPadding)
                        .padding(.bottom, 30)
                    }
                }
            }
            .background(AppColors.background)
            .navigationTitle("故事已生成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .alert("修改建议", isPresented: $aiVM.isEditing) {
                TextField("例如：让结局更温馨、加入更多对话...", text: $aiVM.editSuggestion)
                Button("取消", role: .cancel) {}
                Button("应用修改") {
                    aiVM.applyEdits()
                }
            } message: {
                Text("描述你想要的修改，AI会重新调整故事")
            }
        }
    }
}

// MARK: - 预览
struct AICreateView_Previews: PreviewProvider {
    static var previews: some View {
        AICreateView()
            .environmentObject(AICreateViewModel())
            .environmentObject(PlayerViewModel())
    }
}