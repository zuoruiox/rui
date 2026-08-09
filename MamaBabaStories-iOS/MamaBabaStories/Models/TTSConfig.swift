//
//  TTSConfig.swift
//  MamaBabaStories
//
//  TTS 配置模型
//

import Foundation

// MARK: - TTS 配置
struct TTSConfig: Codable {
    var voiceModelId: String
    var speed: Float  // 0.5 - 2.0
    var pitch: Float  // -12 to 12 semitones
    var volume: Float  // 0.0 - 1.0
    var emotion: TTSemotion
    var enableStreaming: Bool
    var sampleRate: Int
    var format: TTSFormat

    static let `default` = TTSConfig(
        voiceModelId: "",
        speed: 1.0,
        pitch: 0,
        volume: 1.0,
        emotion: .warm,
        enableStreaming: true,
        sampleRate: 24000,
        format: .mp3
    )
}

// MARK: - TTS 音频格式
enum TTSFormat: String, Codable {
    case mp3 = "mp3"
    case wav = "wav"
    case pcm = "pcm"
    case ogg = "ogg"
}

// MARK: - TTS 流式响应块
struct TTSStreamChunk {
    let audioData: Data
    let isLast: Bool
    let sequenceNumber: Int
    let timestamp: TimeInterval
}

// MARK: - WebSocket TTS 消息
enum TTSWebSocketMessage: Codable {
    case start(TTSStartMessage)
    case audio(TTSAudioMessage)
    case end(TTSEndMessage)
    case error(TTSErrorMessage)
    case config(TTSConfigMessage)

    enum MessageType: String, Codable {
        case start
        case audio
        case end
        case error
        case config
    }
}

struct TTSStartMessage: Codable {
    let type: String = "start"
    let text: String
    let voiceModelId: String
    let speed: Float
    let emotion: String
}

struct TTSAudioMessage: Codable {
    let type: String = "audio"
    let data: String  // base64 encoded audio
    let sequence: Int
}

struct TTSEndMessage: Codable {
    let type: String = "end"
    let duration: TimeInterval
}

struct TTSErrorMessage: Codable {
    let type: String = "error"
    let code: Int
    let message: String
}

struct TTSConfigMessage: Codable {
    let type: String = "config"
    let sampleRate: Int
    let format: String
}
