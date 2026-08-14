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
    func createVoiceModel(name: String, ownerType: String) async throws -> VoiceModel
    func deleteVoiceModel(id: String) async throws
    func uploadRecording(voiceModelId: String, audioURL: URL, duration: TimeInterval, progressHandler: ((Double) -> Void)?) async throws -> RecordingSample
    func startTraining(voiceModelId: String) async throws
    func pollTrainingStatus(voiceModelId: String) async throws -> VoiceModel
    func synthesizeSpeech(text: String, voiceModelId: String, config: TTSConfig?) async throws -> URL
}

// MARK: - VoiceCloneService 实现
class VoiceCloneService: VoiceCloneServiceProtocol {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    // MARK: - 获取声音模型列表
    func getVoiceModels() async throws -> [VoiceModel] {
        // 后端直接返回数组，不是 PaginatedResponse
        let models: [VoiceModel] = try await apiClient.request(.getVoiceModels)
        return models
    }

    // MARK: - 创建声音模型
    func createVoiceModel(name: String, ownerType: String) async throws -> VoiceModel {
        return try await apiClient.request(.createVoiceModel(name: name, ownerType: ownerType))
    }

    // MARK: - 删除声音模型
    func deleteVoiceModel(id: String) async throws {
        let _: EmptyResponse? = try await apiClient.requestOptional(.deleteVoiceModel(id: id))
    }

    // MARK: - 上传录音
    func uploadRecording(voiceModelId: String, audioURL: URL, duration: TimeInterval, progressHandler: ((Double) -> Void)?) async throws -> RecordingSample {
        let audioData = try Data(contentsOf: audioURL)

        // 上传录音，后端返回 UploadRecordingResponse
        let response: UploadRecordingResponse = try await apiClient.upload(
            .uploadRecording(voiceModelId: voiceModelId, data: audioData, duration: duration),
            progressHandler: progressHandler
        )
        return response.recording
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
            let voiceModel: VoiceModel = try await apiClient.request(.getVoiceModel(id: voiceModelId))

            switch voiceModel.statusEnum {
            case .ready:
                Logger.info("声音模型训练完成: \(voiceModelId)", category: .voice)
                return voiceModel
            case .failed:
                Logger.error("声音模型训练失败: \(voiceModelId)", category: .voice)
                throw NSError(domain: "VoiceClone", code: -1, userInfo: [NSLocalizedDescriptionKey: voiceModel.errorMessage ?? "声音模型训练失败，请重新录制"])
            case .draft, .recording, .training:
                Logger.debug("训练进度: \(Int(voiceModel.trainingProgress * 100))%", category: .voice)
                try await Task.sleep(nanoseconds: UInt64(VoiceCloneConfig.pollingInterval * 1_000_000_000))
                attempts += 1
            }
        }

        throw NSError(domain: "VoiceClone", code: -2, userInfo: [NSLocalizedDescriptionKey: "训练超时，请稍后查看状态"])
    }

    // MARK: - 语音合成（TTS）
    func synthesizeSpeech(text: String, voiceModelId: String, config: TTSConfig? = nil) async throws -> URL {
        struct TTSResponse: Codable {
            let audioUrl: String
            let duration: Int?
            let voiceModelId: String?
            let format: String?
        }
        let response: TTSResponse = try await apiClient.request(.synthesizeSpeech(voiceModelId: voiceModelId, text: text, config: config))
        let audioUrlString = response.audioUrl

        // 处理URL：完整URL直接返回，相对路径拼接baseURL
        if audioUrlString.hasPrefix("http://") || audioUrlString.hasPrefix("https://") {
            guard let url = URL(string: audioUrlString) else {
                throw NSError(domain: "VoiceClone", code: -1, userInfo: [NSLocalizedDescriptionKey: "音频URL无效"])
            }
            return url
        } else {
            // 相对路径，拼接baseURL
            let base = APIConfig.baseURL
            let separator = audioUrlString.hasPrefix("/") ? "" : "/"
            let fullUrlString: String
            if audioUrlString.hasPrefix("/api/") && base.hasSuffix("/api") {
                // base 已经包含 /api，去掉 urlString 中的 /api 前缀
                let path = String(audioUrlString.dropFirst(4))
                fullUrlString = base + path
            } else {
                fullUrlString = base + separator + audioUrlString
            }
            guard let url = URL(string: fullUrlString) else {
                throw NSError(domain: "VoiceClone", code: -1, userInfo: [NSLocalizedDescriptionKey: "音频URL无效"])
            }
            Logger.info("TTS音频URL: \(fullUrlString)", category: .voice)
            return url
        }
    }
}

// MARK: - Mock VoiceCloneService
class MockVoiceCloneService: VoiceCloneServiceProtocol {
    var mockDelay: TimeInterval = 1.0

    func getVoiceModels() async throws -> [VoiceModel] {
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        return [VoiceModel.mockMom, VoiceModel.mockDad, VoiceModel.mockTraining]
    }

    func createVoiceModel(name: String, ownerType: String) async throws -> VoiceModel {
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        return VoiceModel(
            id: "voice_new_\(UUID().uuidString.prefix(8))",
            name: name,
            ownerType: ownerType,
            emoji: "🎤",
            status: "draft",
            progress: 0,
            quality: "quick",
            previewUrl: nil,
            errorMessage: nil,
            trainedAt: nil,
            createdAt: Date(),
            updatedAt: Date(),
            recordingsCount: 0
        )
    }

    func deleteVoiceModel(id: String) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    func uploadRecording(voiceModelId: String, audioURL: URL, duration: TimeInterval, progressHandler: ((Double) -> Void)?) async throws -> RecordingSample {
        for progress in stride(from: 0.1, through: 1.0, by: 0.1) {
            progressHandler?(progress)
            try await Task.sleep(nanoseconds: 200_000_000)
        }

        return RecordingSample(
            id: "sample_\(UUID().uuidString.prefix(8))",
            voiceModelId: voiceModelId,
            filePath: "/mock/recording.wav",
            duration: Float(duration),
            fileSize: Int((try? Data(contentsOf: audioURL).count) ?? 0),
            quality: nil,
            promptText: nil,
            sortOrder: 0,
            createdAt: Date()
        )
    }

    func startTraining(voiceModelId: String) async throws {
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }

    func pollTrainingStatus(voiceModelId: String) async throws -> VoiceModel {
        for _ in stride(from: 0.2, through: 1.0, by: 0.2) {
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        return VoiceModel.mockMom
    }

    func synthesizeSpeech(text: String, voiceModelId: String, config: TTSConfig?) async throws -> URL {
        try await Task.sleep(nanoseconds: 2_000_000_000)
        return URL(string: "https://example.com/mock-audio.mp3")!
    }
}