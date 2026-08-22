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
    @Published var isCreating = false
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
        return "第 \(currentPromptIndex + 1) 段"
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
        // 不再自动加载，等登录成功后由 App 入口触发 loadData()
    }

    deinit {
        recordingTimer?.invalidate()
        waveformUpdateTimer?.invalidate()
        trainingTask?.cancel()
    }

    // MARK: - 加载数据
    func loadData() async {
        // 游客模式不加载声音模型
        guard let user = AuthService.shared.currentUser, !user.isGuest else {
            voiceModels = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            voiceModels = try await voiceService.getVoiceModels()
            Logger.info("加载了 \(voiceModels.count) 个声音模型", category: .voice)
        } catch {
            Logger.error("加载声音模型失败: \(error)", category: .voice)
            voiceModels = []
        }
    }

    // MARK: - 设置录音器
    private func setupAudioRecorder() {
        audioRecorder.delegate = self
    }

    // MARK: - 创建新声音模型
    func createVoiceModel() async -> Bool {
        guard !newVoiceName.isEmpty else { return false }

        isCreating = true
        errorMessage = nil
        defer { isCreating = false }

        do {
            let model = try await voiceService.createVoiceModel(
                name: newVoiceName,
                ownerType: selectedOwnerType.rawValue
            )
            currentVoiceModel = model
            voiceModels.insert(model, at: 0)
            recordings = []
            currentPromptIndex = 0
            showNameInput = false
            newVoiceName = ""
            navigateToRecording = true
            Logger.info("声音模型创建成功: \(model.id)", category: .voice)
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            Logger.error("创建声音模型失败: \(error)", category: .voice)
            return false
        }
    }

    // MARK: - 选择声音模型
    func selectVoiceModel(_ model: VoiceModel) {
        currentVoiceModel = model
        recordings = []
        currentPromptIndex = model.sampleCount
        navigateToRecording = true
    }

    // MARK: - 开始录音
    func startRecording() {
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

        // 上传录音
        Task {
            isUploading = true
            uploadProgress = 0

            do {
                let uploadedSample = try await voiceService.uploadRecording(
                    voiceModelId: voiceModel.id,
                    audioURL: fileURL,
                    duration: duration
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.uploadProgress = progress
                    }
                }

                recordings.append(uploadedSample)

                // 重新加载模型列表以更新录音数
                if let updatedModels = try? await voiceService.getVoiceModels(),
                   let updatedModel = updatedModels.first(where: { $0.id == voiceModel.id }) {
                    if let index = voiceModels.firstIndex(where: { $0.id == voiceModel.id }) {
                        voiceModels[index] = updatedModel
                    }
                    currentVoiceModel = updatedModel
                }

                isUploading = false
                uploadProgress = 0
                currentPromptIndex += 1
                recordingDuration = 0
            } catch {
                isUploading = false
                errorMessage = "上传失败: \(error.localizedDescription)"
                showError = true
            }
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

                trainingTask = Task {
                    do {
                        let trainedModel = try await voiceService.pollTrainingStatus(voiceModelId: voiceModel.id)

                        await MainActor.run {
                            self.trainingProgress = 1.0
                            self.isTraining = false

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
        errorMessage = "语音合成功能即将上线"
        showError = true
    }

    // MARK: - 取消录音
    func cancelRecording() {
        audioRecorder.cancel()
        isRecording = false
        isPaused = false
        recordingDuration = 0
        recordingTimer?.invalidate()
        waveformUpdateTimer?.invalidate()
        waveformData = Array(repeating: 0, count: 50)
        currentMeterLevel = 0
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
    nonisolated func recorderDidStart(_ recorder: AudioRecorder) {}

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

    nonisolated func recorder(_ recorder: AudioRecorder, didUpdateMeterLevel level: Float) {}
    nonisolated func recorder(_ recorder: AudioRecorder, didDetectVoice isVoice: Bool) {
        Task { @MainActor in
            isVoiceDetected = isVoice
        }
    }
    nonisolated func recorder(_ recorder: AudioRecorder, didUpdateDuration duration: TimeInterval) {}
    nonisolated func recorder(_ recorder: AudioRecorder, didDetectQuality quality: RecordingQuality) {
        Task { @MainActor in
            recordingQuality = quality
        }
    }
}