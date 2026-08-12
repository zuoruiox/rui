//
//  AudioRecorder.swift
//  MamaBabaStories
//
//  音频录音服务 - 基于 AVAudioRecorder（简单可靠，模拟器/真机通用）
//

import Foundation
import AVFoundation

// MARK: - 录音状态
enum RecordingState: Equatable {
    case idle
    case recording
    case paused
    case finished(URL)
    case error(String)
}

// MARK: - 录音代理协议
protocol AudioRecorderDelegate: AnyObject {
    func recorderDidStart(_ recorder: AudioRecorder)
    func recorderDidStop(_ recorder: AudioRecorder, fileURL: URL)
    func recorderDidFail(_ recorder: AudioRecorder, error: Error)
    func recorder(_ recorder: AudioRecorder, didUpdateMeterLevel level: Float)
    func recorder(_ recorder: AudioRecorder, didDetectVoice isVoice: Bool)
    func recorder(_ recorder: AudioRecorder, didUpdateDuration duration: TimeInterval)
    func recorder(_ recorder: AudioRecorder, didDetectQuality quality: RecordingQuality)
}

// MARK: - AudioRecorder
class AudioRecorder: NSObject {
    // MARK: - Properties
    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var durationTimer: Timer?

    // 状态
    private(set) var state: RecordingState = .idle
    private var isRecording = false
    private var isPaused = false
    private var recordingStartTime: Date?
    private var pausedDuration: TimeInterval = 0
    private var pauseStartTime: Date?

    // 音量计量
    private var currentMeterLevel: Float = 0
    private var peakLevel: Float = 0

    // 录音文件
    private var recordingURL: URL?
    private(set) var currentDuration: TimeInterval = 0

    // 代理
    weak var delegate: AudioRecorderDelegate?

    // MARK: - Init
    override init() {
        super.init()
    }

    deinit {
        stop()
    }

    // MARK: - 权限检查
    func requestPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    var hasPermission: Bool {
        return AVAudioSession.sharedInstance().recordPermission == .granted
    }

    // MARK: - 开始录音
    func start() throws {
        guard !isRecording else { return }

        // 配置音频会话
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            throw error
        }

        // 创建录音文件 URL
        let fileName = "recording_\(Date().timeIntervalSince1970).wav"
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documentsDir.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        let url = recordingsDir.appendingPathComponent(fileName)
        recordingURL = url

        // 录音设置：WAV, 16kHz, 16bit, mono（适合语音处理）
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()

            guard let recorder = audioRecorder, recorder.record() else {
                throw NSError(domain: "AudioRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法开始录音"])
            }

            isRecording = true
            isPaused = false
            recordingStartTime = Date()
            currentDuration = 0
            currentMeterLevel = 0
            peakLevel = 0
            state = .recording

            // 启动计时器
            startTimers()

            delegate?.recorderDidStart(self)
        } catch {
            state = .error(error.localizedDescription)
            throw error
        }
    }

    // MARK: - 暂停录音
    func pause() {
        guard isRecording && !isPaused else { return }
        audioRecorder?.pause()
        isPaused = true
        pauseStartTime = Date()
        levelTimer?.invalidate()
        durationTimer?.invalidate()
        state = .paused
    }

    // MARK: - 恢复录音
    func resume() throws {
        guard isPaused else { return }
        if let pauseStart = pauseStartTime {
            pausedDuration += Date().timeIntervalSince(pauseStart)
        }
        isPaused = false
        pauseStartTime = nil
        audioRecorder?.record()
        startTimers()
        state = .recording
    }

    // MARK: - 停止录音
    func stop() {
        guard isRecording || state == .paused else { return }

        levelTimer?.invalidate()
        durationTimer?.invalidate()
        levelTimer = nil
        durationTimer = nil

        audioRecorder?.stop()
        isRecording = false
        isPaused = false

        // 计算最终时长
        if let start = recordingStartTime {
            currentDuration = Date().timeIntervalSince(start) - pausedDuration
        }

        // delegate 会在 audioRecorderDidFinishRecording 中调用
    }

    // MARK: - 取消录音
    func cancel() {
        levelTimer?.invalidate()
        durationTimer?.invalidate()
        levelTimer = nil
        durationTimer = nil

        audioRecorder?.stop()
        audioRecorder?.deleteRecording()
        isRecording = false
        isPaused = false
        currentDuration = 0
        currentMeterLevel = 0
        peakLevel = 0
        recordingStartTime = nil
        pausedDuration = 0
        pauseStartTime = nil
        state = .idle

        restorePlaybackSession()
    }

    // MARK: - 获取当前音量 (0-1)
    var currentVolume: Float {
        return currentMeterLevel
    }

    // MARK: - 获取录音质量
    func getRecordingQuality() -> RecordingQuality {
        let isTooQuiet = peakLevel < 0.05
        let isTooLoud = peakLevel > 0.95
        let hasClipping = peakLevel > 0.98

        var score = 100.0
        if isTooQuiet { score -= 20 }
        if isTooLoud { score -= 15 }
        if hasClipping { score -= 25 }
        score = max(0, min(100, score))

        return RecordingQuality(
            snr: isTooQuiet ? 10 : 30,
            peakLevel: peakLevel,
            hasClipping: hasClipping,
            isTooQuiet: isTooQuiet,
            isTooLoud: isTooLoud,
            overallScore: score
        )
    }

    // MARK: - 私有方法 - 计时器
    private func startTimers() {
        // 音量更新计时器
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            recorder.updateMeters()

            // averagePower 范围 -160dB 到 0dB，转换为 0-1
            let avgPower = recorder.averagePower(forChannel: 0)
            let linearLevel = max(0, min(1, pow(10, avgPower / 20)))

            // 平滑处理
            self.currentMeterLevel = self.currentMeterLevel * 0.7 + linearLevel * 0.3
            if self.currentMeterLevel > self.peakLevel {
                self.peakLevel = self.currentMeterLevel
            }

            DispatchQueue.main.async {
                self.delegate?.recorder(self, didUpdateMeterLevel: self.currentMeterLevel)

                // VAD: 音量超过阈值认为有声音
                let isVoice = linearLevel > 0.02
                self.delegate?.recorder(self, didDetectVoice: isVoice)
            }
        }

        // 时长更新计时器
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.recordingStartTime else { return }
            var duration = Date().timeIntervalSince(start) - self.pausedDuration
            if self.isPaused, let pauseStart = self.pauseStartTime {
                duration -= Date().timeIntervalSince(pauseStart)
            }
            self.currentDuration = max(0, duration)
            DispatchQueue.main.async {
                self.delegate?.recorder(self, didUpdateDuration: self.currentDuration)
            }
        }
    }

    // MARK: - 恢复播放音频会话
    private func restorePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.allowBluetooth, .allowAirPlay])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            // 忽略
        }
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag, let url = recordingURL {
            state = .finished(url)
            let quality = getRecordingQuality()
            delegate?.recorder(self, didDetectQuality: quality)
            delegate?.recorderDidStop(self, fileURL: url)
        } else {
            state = .error("录音失败")
            delegate?.recorderDidFail(self, error: NSError(domain: "AudioRecorder", code: -2, userInfo: [NSLocalizedDescriptionKey: "录音失败"]))
        }
        restorePlaybackSession()
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            state = .error(error.localizedDescription)
            delegate?.recorderDidFail(self, error: error)
        }
        restorePlaybackSession()
    }
}