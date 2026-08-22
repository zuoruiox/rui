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

    // 保存/下载状态
    @Published var isSavingToServer = false
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var savedStory: Story?
    @Published var saveSuccessMessage: String?

    // 编辑
    @Published var isEditing = false
    @Published var editedContent = ""
    @Published var editSuggestion = ""

    // UI 状态
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showingStoryResult = false
    @Published var availableVoiceModels: [VoiceModel] = []

    // MARK: - Services
    private let aiService: AIStoryServiceProtocol
    private let voiceService: VoiceCloneServiceProtocol
    private let audioPlayer: AudioPlayerManager

    // MARK: - Init
    init(aiService: AIStoryServiceProtocol = AIStoryService(),
         voiceService: VoiceCloneServiceProtocol = VoiceCloneService(),
         audioPlayer: AudioPlayerManager = AudioPlayerManager.shared) {
        self.aiService = aiService
        self.voiceService = voiceService
        self.audioPlayer = audioPlayer
    }

    // MARK: - 加载数据
    func loadData() async {
        // 游客模式不加载数据
        guard let user = AuthService.shared.currentUser, !user.isGuest else {
            availableVoiceModels = []
            return
        }

        do {
            availableVoiceModels = try await voiceService.getVoiceModels()
            if selectedVoiceModel == nil {
                selectedVoiceModel = availableVoiceModels.first(where: { $0.statusEnum == .ready })
            }
        } catch {
            Logger.error("加载声音模型失败: \(error)", category: .ai)
            availableVoiceModels = []
        }
    }

    // MARK: - 生成故事
    func generateStory() {
        isGenerating = true
        generationProgress = 0
        generationStage = "正在构思故事..."
        generatedStory = nil
        showingStoryResult = false
        errorMessage = nil
        savedStory = nil
        synthesizedAudioURL = nil
        isSynthesizing = false
        isSavingToServer = false
        isDownloading = false
        downloadProgress = 0
        saveSuccessMessage = nil

        var chars: [String] = []
        if !characterName.isEmpty {
            chars.append(characterName)
        }
        if includeChildName, let child = selectedChild, !child.name.isEmpty {
            chars.append(child.name)
        }

        let request = AIStoryRequest(
            theme: selectedTheme.rawValue,
            characters: chars,
            style: selectedStyle.rawValue,
            targetAge: selectedAgeGroup.rawValue,
            wordCount: selectedWordCount.rawValue,
            customPrompt: customPrompt.isEmpty ? nil : customPrompt,
            childName: includeChildName ? selectedChild?.name : nil,
            voiceModelId: selectedVoiceModel?.id,
            includeMorals: true
        )

        Task {
            do {
                // 模拟进度（同步生成，等待期间显示进度）
                for progress in stride(from: 0.1, through: 0.5, by: 0.1) {
                    try await Task.sleep(nanoseconds: 300_000_000)
                    self.generationProgress = progress
                    if progress > 0.2 {
                        self.generationStage = "AI正在编写故事..."
                    }
                }

                let story = try await aiService.generateStory(request: request)

                self.generationProgress = 0.6
                self.generationStage = "正在润色文字..."
                try await Task.sleep(nanoseconds: 200_000_000)

                self.generatedStory = story
                self.editedContent = story.content
                self.showingStoryResult = true
                self.isGenerating = false

                // 自动开始语音合成（仅合成，不自动保存）
                if self.selectedVoiceModel != nil {
                    await self.synthesizeAudioOnly(for: story)
                } else {
                    self.generationProgress = 1.0
                    self.generationStage = "完成！"
                }
            } catch {
                self.isGenerating = false
                self.errorMessage = error.localizedDescription
                self.showError = true
                Logger.error("生成故事失败: \(error)", category: .ai)
            }
        }
    }

    // MARK: - 仅合成语音（不保存到服务器）
    private func synthesizeAudioOnly(for story: AIStoryResponse) async {
        guard let voiceModel = selectedVoiceModel else { return }

        isSynthesizing = true
        generationStage = "正在合成语音..."
        generationProgress = 0.7

        do {
            let audioURL = try await voiceService.synthesizeSpeech(
                text: editedContent.isEmpty ? story.content : editedContent,
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
            generationProgress = 1.0
            generationStage = "语音合成完成，可以播放或保存"

        } catch {
            isSynthesizing = false
            generationProgress = 1.0
            generationStage = "语音合成失败，可播放文本或重试"
            Logger.warning("语音合成失败: \(error)", category: .ai)
        }
    }

    // MARK: - 手动保存故事到服务器（点击"保存"按钮触发）
    func saveStoryToServer() async -> Bool {
        guard let aiStory = generatedStory else { return false }
        guard !isSavingToServer else { return false }

        isSavingToServer = true
        isDownloading = false
        downloadProgress = 0
        generationStage = "正在保存到故事库..."

        do {
            // 确定音频URL
            let audioURLString = synthesizedAudioURL?.absoluteString

            let story = try await aiService.saveStory(
                aiStory,
                editedContent: editedContent,
                audioURL: audioURLString,
                theme: selectedTheme.rawValue,
                style: selectedStyle.rawValue,
                targetAgeGroup: selectedAgeGroup.rawValue,
                voiceModelId: selectedVoiceModel?.id,
                voiceModelName: selectedVoiceModel?.name
            )

            savedStory = story
            isSavingToServer = false

            // 如果有音频URL，自动下载到本地
            if let audioURLStr = story.audioURL, !audioURLStr.isEmpty {
                generationStage = "正在下载音频..."
                await downloadAudio(for: story)
            } else {
                generationStage = "已保存到故事库"
                saveSuccessMessage = "已保存到故事库"
            }

            // 通知故事库刷新
            NotificationCenter.default.post(name: NSNotification.Name("StoryLibraryNeedsRefresh"), object: nil)
            return true

        } catch {
            isSavingToServer = false
            isDownloading = false
            errorMessage = "保存失败: \(error.localizedDescription)"
            showError = true
            Logger.error("保存故事到服务器失败: \(error)", category: .ai)
            return false
        }
    }

    // MARK: - 下载音频到本地
    private func downloadAudio(for story: Story) async {
        isDownloading = true
        downloadProgress = 0

        do {
            try await audioPlayer.downloadStory(story) { [weak self] progress in
                Task { @MainActor in
                    self?.downloadProgress = progress
                }
            }

            // 更新 savedStory 的本地路径
            let localURL = audioPlayer.localFileURL(for: story.id)
            var updatedStory = story
            updatedStory.localAudioPath = localURL.path
            updatedStory.isDownloaded = true
            savedStory = updatedStory

            isDownloading = false
            downloadProgress = 1.0
            generationStage = "已保存到故事库"
            saveSuccessMessage = "已保存到故事库"

            Logger.info("故事音频下载完成: \(story.title)", category: .ai)

        } catch {
            isDownloading = false
            // 下载失败但故事已保存到服务器
            generationStage = "已保存（音频下载失败）"
            saveSuccessMessage = "已保存到故事库"
            Logger.error("下载音频失败: \(error)", category: .ai)
        }
    }

    // MARK: - 合成语音（公开方法，用于重新合成）
    func synthesizeAudio(for story: AIStoryResponse? = nil, voiceModel: VoiceModel? = nil) async {
        guard let story = story ?? generatedStory else { return }
        await synthesizeAudioOnly(for: story)
    }

    // MARK: - 重新生成
    func regenerateStory() {
        guard let story = generatedStory else { return }
        isGenerating = true
        generationProgress = 0
        generationStage = "正在重新生成..."
        savedStory = nil
        synthesizedAudioURL = nil
        saveSuccessMessage = nil

        Task {
            do {
                let newStory = try await aiService.regenerateStory(storyId: story.storyId)
                generatedStory = newStory
                editedContent = newStory.content
                isGenerating = false

                // 重新合成语音
                if selectedVoiceModel != nil {
                    await synthesizeAudioOnly(for: newStory)
                } else {
                    generationProgress = 1.0
                    generationStage = "完成！"
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
        savedStory = nil
        synthesizedAudioURL = nil
        saveSuccessMessage = nil

        Task {
            do {
                let editedStory = try await aiService.editStory(storyId: story.storyId, edits: editSuggestion)
                generatedStory = editedStory
                editedContent = editedStory.content
                isGenerating = false
                editSuggestion = ""

                // 重新合成语音
                if selectedVoiceModel != nil {
                    await synthesizeAudioOnly(for: editedStory)
                } else {
                    generationProgress = 1.0
                    generationStage = "完成！"
                }
            } catch {
                isGenerating = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    // MARK: - 构建本地 Story 对象（用于播放）
    func buildPlayableStory() -> Story? {
        // 优先使用服务器保存的故事（有正确的 audioURL 和本地路径）
        if let saved = savedStory {
            return saved
        }

        guard let aiStory = generatedStory else { return nil }

        // 确定音频URL：优先本地下载的文件，其次合成的远程URL
        var audioURLString: String? = nil
        var localPath: String? = nil

        if let localURL = synthesizedAudioURL, localURL.isFileURL {
            localPath = localURL.path
        } else {
            audioURLString = synthesizedAudioURL?.absoluteString
        }

        let wordCount = editedContent.replacingOccurrences(of: "\\s", with: "", options: .regularExpression).count

        return Story(
            id: aiStory.storyId,
            title: aiStory.title,
            content: editedContent,
            summary: aiStory.summary,
            theme: selectedTheme.rawValue,
            style: selectedStyle.rawValue,
            targetAgeGroup: selectedAgeGroup.rawValue,
            coverImageURL: nil,
            coverGradient: aiStory.coverGradient,
            coverEmoji: aiStory.coverEmoji,
            audioURL: audioURLString,
            localAudioPath: localPath,
            duration: aiStory.suggestedDuration,
            wordCount: wordCount,
            voiceModelId: selectedVoiceModel?.id,
            voiceModelName: selectedVoiceModel?.name,
            isAIGenerated: true,
            isFavorite: false,
            isDownloaded: localPath != nil,
            playCount: 0,
            createdAt: aiStory.createdAt ?? Date(),
            updatedAt: Date(),
            tags: aiStory.tags,
            characters: aiStory.characters
        )
    }

    // MARK: - 是否已保存
    var isStorySaved: Bool {
        return savedStory != nil
    }

    // MARK: - 是否可以保存
    var canSave: Bool {
        return generatedStory != nil && !isSynthesizing && !isSavingToServer && !isGenerating && !isDownloading
    }

    // MARK: - 播放状态描述
    var playButtonTitle: String {
        if isSynthesizing {
            return "语音合成中..."
        } else if isGenerating {
            return "生成中..."
        } else if isSavingToServer {
            return "保存中..."
        } else if isDownloading {
            return "下载中 \(Int(downloadProgress * 100))%"
        } else {
            return "播放故事"
        }
    }

    var isPlayButtonDisabled: Bool {
        return isSynthesizing || isGenerating
    }

    // MARK: - 保存按钮标题
    var saveButtonTitle: String {
        if isSavingToServer {
            return "保存中..."
        } else if isDownloading {
            return "下载中..."
        } else if isStorySaved {
            return "已保存"
        } else {
            return "保存"
        }
    }

    var isSaveButtonDisabled: Bool {
        return !canSave || isStorySaved
    }

    // MARK: - 重置
    func reset() {
        generatedStory = nil
        synthesizedAudioURL = nil
        savedStory = nil
        showingStoryResult = false
        isEditing = false
        editedContent = ""
        editSuggestion = ""
        generationProgress = 0
        isSynthesizing = false
        isSavingToServer = false
        isDownloading = false
        downloadProgress = 0
        saveSuccessMessage = nil
        customPrompt = ""
        characterName = ""
    }

    // MARK: - 表单验证
    var canGenerate: Bool {
        !isGenerating
    }

    // MARK: - 字数估算
    var estimatedDuration: String {
        let minutes = Int(selectedWordCount.estimatedDuration) / 60
        let seconds = Int(selectedWordCount.estimatedDuration) % 60
        return "约\(minutes)分\(seconds)秒"
    }
}
