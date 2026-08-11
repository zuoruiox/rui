//
//  VoiceCloneService.swift
//  MamaBabaStories
//
//  声音克隆服务 - 管理录音上传、训练状态轮询、语音合成
//

import Foundation
import Combine

// MARK: - 声音克隆服务协议
protocol VoiceCloneServiceProtocol {
    func getVoiceModels() async throws -> [VoiceModel]
    func createVoiceModel(name: String, ownerType: VoiceOwnerType) async throws -> VoiceModel
    func deleteVoiceModel(id: String) async throws
    func uploadRecording(voiceModelId: String, audioURL: URL, duration: TimeInterval, progressHandler: ((Double) -> Void)?) async throws -> RecordingSample
    func startTraining(voiceModelId: String) async throws
    func pollTrainingStatus(voiceModelId: String) async throws -> VoiceModel
    func synthesizeSpeech(text: String, voiceModelId: String, config: TTSConfig?) async throws -> URL
    func setDefaultVoice(id: String) async throws
}

// MARK: - VoiceCloneService 实现
class VoiceCloneService: VoiceCloneServiceProtocol {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    // MARK: - 获取声音模型列表
    func getVoiceModels() async throws -> [VoiceModel] {
        let response: PaginatedResponse<VoiceModel> = try await apiClient.request(.getVoiceModels)
        return response.list
    }

    // MARK: - 创建声音模型
    func createVoiceModel(name: String, ownerType: VoiceOwnerType) async throws -> VoiceModel {
        return try await apiClient.request(.createVoiceModel(name: name, ownerType: ownerType.rawValue))
    }

    // MARK: - 删除声音模型
    func deleteVoiceModel(id: String) async throws {
        let _: EmptyResponse? = try await apiClient.requestOptional(.deleteVoiceModel(id: id))
    }

    // MARK: - 上传录音
    func uploadRecording(voiceModelId: String, audioURL: URL, duration: TimeInterval, progressHandler: ((Double) -> Void)?) async throws -> RecordingSample {
        // 读取音频文件数据
        let audioData = try Data(contentsOf: audioURL)

        // 上传
        let sample: RecordingSample = try await apiClient.upload(
            .uploadRecording(voiceModelId: voiceModelId, data: audioData, duration: duration),
            progressHandler: progressHandler
        )
        return sample
    }

    // MARK: - 开始训练
    func startTraining(voiceModelId: String) async throws {
        let _: EmptyResponse? = try await apiClient.requestOptional(.startTraining(voiceModelId: voiceModelId))
        Logger.info("开始训练声音模型: \(voiceModelId)", category: .voice)
    }

    // MARK: - 轮询训练状态
    func pollTrainingStatus(voiceModelId: String) async throws -> VoiceModel {
        var attempts = 0
        let maxAttempts = VoiceCloneConfig.maxPollingAttempts

        while attempts < maxAttempts {
            let voiceModel: VoiceModel = try await apiClient.request(.getTrainingStatus(voiceModelId: voiceModelId))

            switch voiceModel.status {
            case .ready:
                Logger.info("声音模型训练完成: \(voiceModelId)", category: .voice)
                return voiceModel
            case .failed:
                Logger.error("声音模型训练失败: \(voiceModelId)", category: .voice)
                throw NSError(domain: "VoiceClone", code: -1, userInfo: [NSLocalizedDescriptionKey: "声音模型训练失败，请重新录制"])
            case .training, .uploading, .recording:
                Logger.debug("训练进度: \(Int(voiceModel.trainingProgress * 100))%", category: .voice)
                try await Task.sleep(nanoseconds: UInt64(VoiceCloneConfig.pollingInterval * 1_000_000_000))
                attempts += 1
            }
        }

        throw NSError(domain: "VoiceClone", code: -2, userInfo: [NSLocalizedDescriptionKey: "训练超时，请稍后查看状态"])
    }

    // MARK: - 语音合成（TTS）
    func synthesizeSpeech(text: String, voiceModelId: String, config: TTSConfig? = nil) async throws -> URL {
        let response: TTSSynthesisResponse = try await apiClient.request(
            .synthesizeSpeech(voiceModelId: voiceModelId, text: text, config: config)
        )

        // 如果是异步合成，轮询等待完成
        if response.status == "processing" || response.status == "pending" {
            return try await pollSynthesisStatus(taskId: response.taskId)
        }

        guard let audioURLString = response.audioUrl,
              let url = URL(string: audioURLString) else {
            throw NSError(domain: "VoiceClone", code: -3, userInfo: [NSLocalizedDescriptionKey: "合成音频URL无效"])
        }

        return url
    }

    // MARK: - 轮询合成状态
    private func pollSynthesisStatus(taskId: String) async throws -> URL {
        for _ in 0..<60 { // 最多等60次，每次2秒
            try await Task.sleep(nanoseconds: 2_000_000_000)

            let response: TTSSynthesisResponse = try await apiClient.request(.getTTSStatus(taskId: taskId))

            if response.status == "completed", let urlString = response.audioUrl, let url = URL(string: urlString) {
                return url
            }

            if response.status == "failed" {
                throw NSError(domain: "VoiceClone", code: -4, userInfo: [NSLocalizedDescriptionKey: "语音合成失败"])
            }
        }

        throw NSError(domain: "VoiceClone", code: -5, userInfo: [NSLocalizedDescriptionKey: "语音合成超时"])
    }

    // MARK: - 设置默认声音
    func setDefaultVoice(id: String) async throws {
        let _: EmptyResponse? = try await apiClient.requestOptional(.setDefaultVoice(id: id))
    }
}

// MARK: - Mock VoiceCloneService
class MockVoiceCloneService: VoiceCloneServiceProtocol {
    var mockDelay: TimeInterval = 1.0

    func getVoiceModels() async throws -> [VoiceModel] {
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        return [VoiceModel.mockMom, VoiceModel.mockDad, VoiceModel.mockTraining]
    }

    func createVoiceModel(name: String, ownerType: VoiceOwnerType) async throws -> VoiceModel {
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        return VoiceModel(
            id: "voice_new_\(UUID().uuidString.prefix(8))",
            name: name,
            ownerType: ownerType,
            ownerName: ownerType.rawValue,
            status: .recording,
            trainingProgress: 0,
            sampleCount: 0,
            durationSeconds: 0,
            coverColor: nil,
            createdAt: Date(),
            updatedAt: Date(),
            lastUsedAt: nil,
            isDefault: false
        )
    }

    func deleteVoiceModel(id: String) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    func uploadRecording(voiceModelId: String, audioURL: URL, duration: TimeInterval, progressHandler: ((Double) -> Void)?) async throws -> RecordingSample {
        // 模拟上传进度
        for progress in stride(from: 0.1, through: 1.0, by: 0.1) {
            progressHandler?(progress)
            try await Task.sleep(nanoseconds: 200_000_000)
        }

        return RecordingSample(
            id: "sample_\(UUID().uuidString.prefix(8))",
            voiceModelId: voiceModelId,
            localURL: audioURL,
            remoteURL: nil,
            duration: duration,
            fileSize: Int64((try? Data(contentsOf: audioURL).count) ?? 0),
            quality: RecordingQuality(
                snr: 35,
                peakLevel: 0.7,
                hasClipping: false,
                isTooQuiet: false,
                isTooLoud: false,
                overallScore: 85
            ),
            createdAt: Date(),
            isUploaded: true,
            uploadProgress: 1.0
        )
    }

    func startTraining(voiceModelId: String) async throws {
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }

    func pollTrainingStatus(voiceModelId: String) async throws -> VoiceModel {
        // 模拟训练进度
        for progress in stride(from: 0.2, through: 1.0, by: 0.2) {
            try await Task.sleep(nanoseconds: 500_000_000)
            if progress >= 1.0 {
                return VoiceModel.mockMom
            }
        }
        return VoiceModel.mockMom
    }

    func synthesizeSpeech(text: String, voiceModelId: String, config: TTSConfig?) async throws -> URL {
        try await Task.sleep(nanoseconds: 2_000_000_000)
        // 返回一个临时 URL（mock）
        return URL(string: "https://example.com/mock-audio.mp3")!
    }

    func setDefaultVoice(id: String) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
    }
}
