//
//  AICreateViewModel.swift
//  MamaBabaStories
//
//  AI 创作 ViewModel
//

import Foundation
import Combine
import SwiftUI

@MainActor
class AICreateViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedTheme: StoryTheme = .adventure
    @Published var selectedStyle: StoryStyle = .warm
    @Published var selectedAgeGroup: AgeGroup = .preschool
    @Published var selectedWordCount: WordCountOption = .medium_500
    @Published var selectedEmotion: TTSemotion = .warm
    @Published var characterName = ""
    @Published var customPrompt = ""
    @Published var selectedVoiceModel: VoiceModel?
    @Published var includeChildName = false
    @Published var selectedChild: Child?

    // 生成状态
    @Published var isGenerating = false
    @Published var generationProgress: Double = 0
    @Published var generationStage: String = ""
    @Published var generatedStory: AIStoryResponse?
    @Published var isSynthesizing = false
    @Published var synthesizedAudioURL: URL?

    // 编辑
    @Published var isEditing = false
    @Published var editedContent = ""
    @Published var editSuggestion = ""

    // UI 状态
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showingStoryResult = false
    @Published var showingVoiceSelector = false
    @Published var availableVoiceModels: [VoiceModel] = []

    // MARK: - Services
    private let aiService: AIStoryServiceProtocol
    private let voiceService: VoiceCloneServiceProtocol

    // MARK: - Init
    init(aiService: AIStoryServiceProtocol = MockAIStoryService(), voiceService: VoiceCloneServiceProtocol = VoiceCloneService()) {
        self.aiService = aiService
        self.voiceService = voiceService
        loadMockData()
    }

    // MARK: - 加载数据
    func loadData() async {
        do {
            availableVoiceModels = try await voiceService.getVoiceModels()
            if selectedVoiceModel == nil {
                selectedVoiceModel = availableVoiceModels.first(where: { $0.status == .ready })
            }
        } catch {
            // 加载失败时使用 mock 数据
            loadMockData()
        }
    }

    // MARK: - Mock 数据
    private func loadMockData() {
        availableVoiceModels = [VoiceModel.mockMom, VoiceModel.mockDad]
        selectedVoiceModel = VoiceModel.mockMom
        selectedChild = Child.mock
    }

    // MARK: - 生成故事
    func generateStory() {
        isGenerating = true
        generationProgress = 0
        generationStage = "正在构思故事..."
        generatedStory = nil
        showingStoryResult = false

        let request = AIStoryRequest(
            theme: selectedTheme,
            characters: characterName.isEmpty ? [] : [characterName],
            style: selectedStyle,
            targetAge: selectedAgeGroup,
            wordCount: selectedWordCount.rawValue,
            customPrompt: customPrompt.isEmpty ? nil : customPrompt,
            childName: includeChildName ? selectedChild?.name : nil,
            includeMorals: true
        )

        Task {
            do {
                // 模拟进度
                for progress in stride(from: 0.1, through: 0.9, by: 0.15) {
                    try await Task.sleep(nanoseconds: 300_000_000)
                    self.generationProgress = progress
                    if progress > 0.3 {
                        self.generationStage = "正在编写故事内容..."
                    }
                    if progress > 0.6 {
                        self.generationStage = "正在润色文字..."
                    }
                }

                let story = try await aiService.generateStory(request: request)

                self.generationProgress = 1.0
                self.generationStage = "完成！"
                self.generatedStory = story
                self.editedContent = story.content
                self.showingStoryResult = true
                self.isGenerating = false

                // 如果选择了声音模型，自动合成语音
                if let voiceModel = selectedVoiceModel, voiceModel.status == .ready {
                    await synthesizeAudio(for: story, voiceModel: voiceModel)
                }
            } catch {
                self.isGenerating = false
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }

    // MARK: - 合成语音
    func synthesizeAudio(for story: AIStoryResponse? = nil, voiceModel: VoiceModel? = nil) async {
        guard let story = story ?? generatedStory,
              let voiceModel = voiceModel ?? selectedVoiceModel else { return }

        isSynthesizing = true

        do {
            let audioURL = try await voiceService.synthesizeSpeech(
                text: story.content,
                voiceModelId: voiceModel.id,
                config: TTSConfig(
                    voiceModelId: voiceModel.id,
                    speed: 1.0,
                    pitch: 0,
                    volume: 1.0,
                    emotion: selectedEmotion,
                    enableStreaming: true,
                    sampleRate: 24000,
                    format: .mp3
                )
            )
            synthesizedAudioURL = audioURL
            isSynthesizing = false
        } catch {
            isSynthesizing = false
            errorMessage = "语音合成失败: \(error.localizedDescription)"
            showError = true
        }
    }

    // MARK: - 重新生成
    func regenerateStory() {
        guard let story = generatedStory else { return }
        isGenerating = true
        generationProgress = 0
        generationStage = "正在重新生成..."

        Task {
            do {
                let newStory = try await aiService.regenerateStory(storyId: story.storyId)
                generatedStory = newStory
                editedContent = newStory.content
                isGenerating = false
                synthesizedAudioURL = nil

                if let voiceModel = selectedVoiceModel, voiceModel.status == .ready {
                    await synthesizeAudio(for: newStory, voiceModel: voiceModel)
                }
            } catch {
                isGenerating = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    // MARK: - 编辑故事
    func applyEdits() {
        guard let story = generatedStory, !editSuggestion.isEmpty else { return }
        isEditing = false
        isGenerating = true
        generationStage = "正在修改故事..."

        Task {
            do {
                let editedStory = try await aiService.editStory(storyId: story.storyId, edits: editSuggestion)
                generatedStory = editedStory
                editedContent = editedStory.content
                isGenerating = false
                editSuggestion = ""
                synthesizedAudioURL = nil
            } catch {
                isGenerating = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    // MARK: - 保存故事
    func saveStory() -> Story? {
        guard let aiStory = generatedStory else { return nil }

        let story = Story(
            id: aiStory.storyId,
            title: aiStory.title,
            content: editedContent,
            summary: aiStory.summary,
            theme: selectedTheme,
            style: selectedStyle,
            targetAgeGroup: selectedAgeGroup,
            coverImageURL: nil,
            coverGradient: aiStory.coverGradient,
            coverEmoji: aiStory.coverEmoji,
            audioURL: synthesizedAudioURL?.absoluteString,
            localAudioPath: nil,
            duration: aiStory.suggestedDuration,
            wordCount: editedContent.count,
            voiceModelId: selectedVoiceModel?.id,
            voiceModelName: selectedVoiceModel?.name,
            isAIGenerated: true,
            isFavorite: false,
            isDownloaded: false,
            playCount: 0,
            createdAt: Date(),
            updatedAt: Date(),
            tags: aiStory.tags,
            characters: aiStory.characters
        )

        return story
    }

    // MARK: - 播放生成的故事
    func playGeneratedStory(playerVM: PlayerViewModel) {
        guard let story = saveStory() else { return }
        playerVM.play(story: story)
    }

    // MARK: - 重置
    func reset() {
        generatedStory = nil
        synthesizedAudioURL = nil
        showingStoryResult = false
        isEditing = false
        editedContent = ""
        editSuggestion = ""
        generationProgress = 0
        customPrompt = ""
        characterName = ""
    }

    // MARK: - 表单验证
    var canGenerate: Bool {
        !isGenerating && selectedVoiceModel != nil
    }

    // MARK: - 字数估算
    var estimatedDuration: String {
        let minutes = Int(selectedWordCount.estimatedDuration) / 60
        let seconds = Int(selectedWordCount.estimatedDuration) % 60
        return "约\(minutes)分\(seconds)秒"
    }
}
