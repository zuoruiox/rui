//
//  VoiceCloneViewModel.swift
//  MamaBabaStories
//
//  声音克隆 ViewModel
//

import Foundation
import Combine
import SwiftUI

@MainActor
class VoiceCloneViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var voiceModels: [VoiceModel] = []
    @Published var currentVoiceModel: VoiceModel?
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var currentMeterLevel: Float = 0
    @Published var waveformData: [Float] = Array(repeating: 0, count: 50)
    @Published var isVoiceDetected = false
    @Published var recordingQuality: RecordingQuality?
    @Published var recordings: [RecordingSample] = []
    @Published var currentPromptIndex = 0
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var isTraining = false
    @Published var trainingProgress: Double = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showNameInput = false
    @Published var newVoiceName = ""
    @Published var selectedOwnerType: VoiceOwnerType = .mom
    @Published var navigateToRecording = false
    @Published var showingTrainingSuccess = false

    // MARK: - Services
    private let audioRecorder = AudioRecorder()
    private let voiceService: VoiceCloneServiceProtocol
    private var recordingTimer: Timer?
    private var waveformUpdateTimer: Timer?
    private var trainingTask: Task<Void, Never>?

    // MARK: - Computed Properties
    var currentPrompt: RecordingPrompt {
        RecordingPrompt.prompts[currentPromptIndex % RecordingPrompt.prompts.count]
    }

    var canStartTraining: Bool {
        recordings.count >= VoiceCloneConfig.minRecordings
    }

    var progressText: String {
        let current = min(currentPromptIndex + 1, RecordingPrompt.prompts.count)
        return "第 \(current) 段 / 共 \(VoiceCloneConfig.maxRecordings) 段"
    }

    var recordingProgress: Double {
        let minDuration = AudioConfig.minRecordingDuration
        return min(recordingDuration / minDuration, 1.0)
    }

    var isRecordingLongEnough: Bool {
        recordingDuration >= AudioConfig.minRecordingDuration
    }

    // MARK: - Init
    init(voiceService: VoiceCloneServiceProtocol = VoiceCloneService()) {
        self.voiceService = voiceService
        setupAudioRecorder()
        loadMockData()
    }

    deinit {
        recordingTimer?.invalidate()
        waveformUpdateTimer?.invalidate()
        trainingTask?.cancel()
    }

    // MARK: - 加载数据
    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            voiceModels = try await voiceService.getVoiceModels()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Mock 数据
    private func loadMockData() {
        voiceModels = [VoiceModel.mockMom, VoiceModel.mockDad, VoiceModel.mockTraining]
    }

    // MARK: - 设置录音器
    private func setupAudioRecorder() {
        audioRecorder.delegate = self
    }

    // MARK: - 创建新声音模型
    func createVoiceModel() async {
        guard !newVoiceName.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let model = try await voiceService.createVoiceModel(
                name: newVoiceName,
                ownerType: selectedOwnerType
            )
            currentVoiceModel = model
            voiceModels.insert(model, at: 0)
            recordings = []
            currentPromptIndex = 0
            showNameInput = false
            newVoiceName = ""
            navigateToRecording = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - 选择声音模型
    func selectVoiceModel(_ model: VoiceModel) {
        currentVoiceModel = model
        // 加载该模型的录音样本
        recordings = []
        currentPromptIndex = 0
    }

    // MARK: - 开始录音
    func startRecording() {
        // 检查权限
        if !audioRecorder.hasPermission {
            Task {
                let granted = await audioRecorder.requestPermission()
                if granted {
                    beginRecording()
                } else {
                    errorMessage = "请在设置中允许麦克风权限"
                    showError = true
                }
            }
        } else {
            beginRecording()
        }
    }

    private func beginRecording() {
        do {
            try audioRecorder.start()
            isRecording = true
            isPaused = false
            recordingDuration = 0
            currentMeterLevel = 0
            waveformData = Array(repeating: 0, count: 50)

            // 启动计时器更新时长
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.recordingDuration = self?.audioRecorder.currentDuration ?? 0
                }
            }

            // 启动波形更新
            waveformUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.currentMeterLevel = self.audioRecorder.currentVolume
                    // 更新波形
                    var newWaveform = self.waveformData
                    newWaveform.removeFirst()
                    newWaveform.append(self.currentMeterLevel)
                    self.waveformData = newWaveform
                }
            }
        } catch {
            errorMessage = "录音启动失败: \(error.localizedDescription)"
            showError = true
        }
    }

    // MARK: - 暂停录音
    func pauseRecording() {
        audioRecorder.pause()
        isPaused = true
        recordingTimer?.invalidate()
        waveformUpdateTimer?.invalidate()
    }

    // MARK: - 恢复录音
    func resumeRecording() {
        do {
            try audioRecorder.resume()
            isPaused = false

            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.recordingDuration = self?.audioRecorder.currentDuration ?? 0
                }
            }

            waveformUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.currentMeterLevel = self.audioRecorder.currentVolume
                    var newWaveform = self.waveformData
                    newWaveform.removeFirst()
                    newWaveform.append(self.currentMeterLevel)
                    self.waveformData = newWaveform
                }
            }
        } catch {
            errorMessage = "恢复录音失败: \(error.localizedDescription)"
            showError = true
        }
    }

    // MARK: - 停止录音
    func stopRecording() {
        audioRecorder.stop()
        isRecording = false
        isPaused = false
        recordingTimer?.invalidate()
        waveformUpdateTimer?.invalidate()
    }

    // MARK: - 完成录音并上传
    func finishRecordingAndUpload(fileURL: URL) {
        guard let voiceModel = currentVoiceModel else { return }

        let duration = recordingDuration
        let quality = audioRecorder.getRecordingQuality()
        recordingQuality = quality

        // 创建本地录音样本
        let sample = RecordingSample(
            id: "local_\(Date().timeIntervalSince1970)",
            voiceModelId: voiceModel.id,
            localURL: fileURL,
            remoteURL: nil,
            duration: duration,
            fileSize: (try? Data(contentsOf: fileURL).count) ?? 0,
            quality: quality,
            createdAt: Date(),
            isUploaded: false,
            uploadProgress: 0
        )
        recordings.append(sample)

        // 上传录音
        Task {
            await uploadRecording(sample: sample, fileURL: fileURL)
        }

        // 进入下一段
        currentPromptIndex += 1
        recordingDuration = 0
    }

    // MARK: - 上传录音
    private func uploadRecording(sample: RecordingSample, fileURL: URL) async {
        guard let voiceModel = currentVoiceModel else { return }

        isUploading = true
        uploadProgress = 0

        do {
            let uploadedSample = try await voiceService.uploadRecording(
                voiceModelId: voiceModel.id,
                audioURL: fileURL,
                duration: sample.duration
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.uploadProgress = progress
                }
            }

            // 更新录音列表
            if let index = recordings.firstIndex(where: { $0.id == sample.id }) {
                recordings[index] = uploadedSample
            }

            isUploading = false
            uploadProgress = 0
        } catch {
            isUploading = false
            errorMessage = "上传失败: \(error.localizedDescription)"
            showError = true
        }
    }

    // MARK: - 开始训练
    func startTraining() {
        guard let voiceModel = currentVoiceModel, canStartTraining else { return }

        isTraining = true
        trainingProgress = 0

        Task {
            do {
                try await voiceService.startTraining(voiceModelId: voiceModel.id)

                // 轮询训练状态
                trainingTask = Task {
                    do {
                        let trainedModel = try await voiceService.pollTrainingStatus(voiceModelId: voiceModel.id)

                        await MainActor.run {
                            self.trainingProgress = 1.0
                            self.isTraining = false

                            // 更新模型列表
                            if let index = self.voiceModels.firstIndex(where: { $0.id == voiceModel.id }) {
                                self.voiceModels[index] = trainedModel
                            }
                            self.currentVoiceModel = trainedModel
                            self.showingTrainingSuccess = true
                        }
                    } catch {
                        await MainActor.run {
                            self.isTraining = false
                            self.errorMessage = error.localizedDescription
                            self.showError = true
                        }
                    }
                }

                // 模拟进度更新
                while isTraining && trainingProgress < 0.95 {
                    try await Task.sleep(nanoseconds: 500_000_000)
                    await MainActor.run {
                        self.trainingProgress += 0.05
                    }
                }
            } catch {
                await MainActor.run {
                    self.isTraining = false
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }

    // MARK: - 删除声音模型
    func deleteVoiceModel(_ model: VoiceModel) async {
        do {
            try await voiceService.deleteVoiceModel(id: model.id)
            voiceModels.removeAll { $0.id == model.id }
            if currentVoiceModel?.id == model.id {
                currentVoiceModel = nil
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - 试听声音
    func tryVoiceModel(_ model: VoiceModel, text: String = "你好呀，宝贝！我是妈妈，今天给你讲一个好听的故事。") {
        Task {
            do {
                let audioURL = try await voiceService.synthesizeSpeech(text: text, voiceModelId: model.id)
                AudioPlayerManager.shared.play(story: Story(
                    id: "preview_\(model.id)",
                    title: "试听 - \(model.name)",
                    content: text,
                    summary: nil,
                    theme: .family,
                    style: .warm,
                    targetAgeGroup: .preschool,
                    coverImageURL: nil,
                    coverGradient: nil,
                    coverEmoji: model.ownerType.emoji,
                    audioURL: audioURL.absoluteString,
                    localAudioPath: nil,
                    duration: 5,
                    wordCount: text.count,
                    voiceModelId: model.id,
                    voiceModelName: model.name,
                    isAIGenerated: false,
                    isFavorite: false,
                    isDownloaded: false,
                    playCount: 0,
                    createdAt: Date(),
                    updatedAt: Date(),
                    tags: [],
                    characters: nil
                ))
            } catch {
                errorMessage = "语音合成失败: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    // MARK: - 重置录音流程
    func resetRecordingFlow() {
        recordings = []
        currentPromptIndex = 0
        recordingDuration = 0
        currentVoiceModel = nil
        navigateToRecording = false
    }

    // MARK: - 删除录音样本
    func removeRecording(at index: Int) {
        guard index < recordings.count else { return }
        recordings.remove(at: index)
    }
}

// MARK: - AudioRecorderDelegate
extension VoiceCloneViewModel: AudioRecorderDelegate {
    nonisolated func recorderDidStart(_ recorder: AudioRecorder) {
        // 已在 startRecording 中处理
    }

    nonisolated func recorderDidStop(_ recorder: AudioRecorder, fileURL: URL) {
        Task { @MainActor in
            finishRecordingAndUpload(fileURL: fileURL)
        }
    }

    nonisolated func recorderDidFail(_ recorder: AudioRecorder, error: Error) {
        Task { @MainActor in
            isRecording = false
            isPaused = false
            recordingTimer?.invalidate()
            waveformUpdateTimer?.invalidate()
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    nonisolated func recorder(_ recorder: AudioRecorder, didUpdateMeterLevel level: Float) {
        // 已在 timer 中处理
    }

    nonisolated func recorder(_ recorder: AudioRecorder, didDetectVoice isVoice: Bool) {
        Task { @MainActor in
            isVoiceDetected = isVoice
        }
    }

    nonisolated func recorder(_ recorder: AudioRecorder, didUpdateDuration duration: TimeInterval) {
        // 已在 timer 中处理
    }

    nonisolated func recorder(_ recorder: AudioRecorder, didDetectQuality quality: RecordingQuality) {
        Task { @MainActor in
            recordingQuality = quality
        }
    }
}
