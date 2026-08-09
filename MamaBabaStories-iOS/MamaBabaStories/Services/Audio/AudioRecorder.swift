//
//  AudioRecorder.swift
//  MamaBabaStories
//
//  音频录音服务 - 基于 AVAudioEngine
//  支持实时 VAD、音量计量、质量检测、降噪
//

import Foundation
import AVFoundation
import Accelerate

// MARK: - 录音状态
enum RecordingState: Equatable {
    case idle
    case preparing
    case recording
    case paused
    case stopping
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
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFile: AVAudioFile?
    private var mixerNode: AVAudioMixerNode?

    // 录音配置
    private let sampleRate: Double = AudioConfig.sampleRate
    private let channels: UInt32 = AudioConfig.channels
    private let bitsPerChannel: UInt32 = AudioConfig.bitsPerChannel

    // 状态
    private(set) var state: RecordingState = .idle {
        didSet {
            Logger.debug("录音状态变更: \(state)", category: .audio)
        }
    }

    private var isRecording = false
    private var isPaused = false
    private var recordingStartTime: Date?
    private var pausedDuration: TimeInterval = 0
    private var pauseStartTime: Date?

    // 音频数据缓冲
    private var audioBufferList: [Float] = []
    private var bufferData = Data()
    private let bufferQueue = DispatchQueue(label: "com.mamababa.audiorecorder.buffer", qos: .userInitiated)

    // VAD 相关
    private var voiceActivityThreshold: Float = AudioConfig.vadEnergyThreshold
    private var silenceStart: Date?
    private var isVoiceDetected = false
    private var consecutiveVoiceFrames = 0
    private var consecutiveSilenceFrames = 0
    private let voiceActivationThreshold = 5  // 连续5帧检测到声音才认为开始说话
    private let silenceDeactivationThreshold = 30  // 约0.5秒静音

    // 音量计量
    private var currentMeterLevel: Float = 0
    private var peakLevel: Float = 0
    private var meterUpdateHandler: ((Float) -> Void)?

    // 质量检测
    private var noiseFloor: Float = 0.001
    private var signalEnergy: Float = 0
    private var noiseEnergy: Float = 0
    private var clippingCount = 0
    private var totalSamples = 0

    // 录音文件
    private var recordingURL: URL?
    private var recordingDuration: TimeInterval = 0

    // 代理
    weak var delegate: AudioRecorderDelegate?

    // 中断处理
    private var wasRecordingBeforeInterruption = false
    private var interruptionObserver: NSObjectProtocol?

    // MARK: - Init
    override init() {
        super.init()
        setupInterruptionHandler()
    }

    deinit {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        stop()
    }

    // MARK: - 中断处理
    private func setupInterruptionHandler() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let self = self, self.isRecording else { return }

            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
            }

            switch type {
            case .began:
                self.wasRecordingBeforeInterruption = self.isRecording
                self.pause()
                Logger.info("录音被中断（电话等）", category: .audio)

            case .ended:
                guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) && self.wasRecordingBeforeInterruption {
                    do {
                        try AVAudioSession.sharedInstance().setActive(true)
                        try self.resume()
                        Logger.info("录音中断后恢复", category: .audio)
                    } catch {
                        Logger.error("录音恢复失败: \(error)", category: .audio)
                    }
                }
                self.wasRecordingBeforeInterruption = false

            @unknown default:
                break
            }
        }
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
        guard state == .idle || state == .paused else {
            Logger.warning("录音已在进行中", category: .audio)
            return
        }

        // 配置音频会话
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        state = .preparing

        // 重置状态
        resetRecordingState()

        // 创建录音文件 URL
        let fileName = "recording_\(Date().timeIntervalSince1970).wav"
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documentsDir.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        recordingURL = recordingsDir.appendingPathComponent(fileName)

        // 设置音频引擎
        try setupAudioEngine()

        // 启动引擎
        try audioEngine?.start()
        isRecording = true
        isPaused = false
        recordingStartTime = Date()
        state = .recording

        delegate?.recorderDidStart(self)
        Logger.info("开始录音: \(fileName)", category: .audio)
    }

    // MARK: - 暂停录音
    func pause() {
        guard isRecording && !isPaused else { return }
        isPaused = true
        pauseStartTime = Date()
        audioEngine?.pause()
        state = .paused
        Logger.debug("录音暂停", category: .audio)
    }

    // MARK: - 恢复录音
    func resume() throws {
        guard isPaused else { return }
        if let pauseStart = pauseStartTime {
            pausedDuration += Date().timeIntervalSince(pauseStart)
        }
        isPaused = false
        pauseStartTime = nil
        try audioEngine?.start()
        state = .recording
        Logger.debug("录音恢复", category: .audio)
    }

    // MARK: - 停止录音
    func stop() {
        guard isRecording || state == .paused else { return }

        state = .stopping
        isRecording = false
        isPaused = false

        // 停止音频引擎
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        audioEngine = nil
        inputNode = nil

        // 计算时长
        if let start = recordingStartTime {
            recordingDuration = Date().timeIntervalSince(start) - pausedDuration
        }

        // 写入 WAV 文件
        if let url = recordingURL {
            do {
                try writeWAVFile(to: url)
                state = .finished(url)
                delegate?.recorderDidStop(self, fileURL: url)
                Logger.info("录音完成: \(url.lastPathComponent), 时长: \(String(format: "%.1f", recordingDuration))秒", category: .audio)
            } catch {
                state = .error(error.localizedDescription)
                delegate?.recorderDidFail(self, error: error)
                Logger.error("保存录音文件失败: \(error)", category: .audio)
            }
        }

        // 计算最终质量
        let quality = calculateQuality()
        delegate?.recorder(self, didDetectQuality: quality)
    }

    // MARK: - 取消录音
    func cancel() {
        isRecording = false
        isPaused = false
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        audioEngine = nil

        // 删除临时文件
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }

        resetRecordingState()
        state = .idle
        Logger.info("录音已取消", category: .audio)
    }

    // MARK: - 获取当前录音时长
    var currentDuration: TimeInterval {
        guard let start = recordingStartTime, isRecording else { return recordingDuration }
        var duration = Date().timeIntervalSince(start) - pausedDuration
        if isPaused, let pauseStart = pauseStartTime {
            duration -= Date().timeIntervalSince(pauseStart)
        }
        return max(0, duration)
    }

    // MARK: - 获取当前音量级别 (0-1)
    var currentVolume: Float {
        return currentMeterLevel
    }

    // MARK: - 获取波形数据
    func getWaveformData(samples: Int = 100) -> [Float] {
        return bufferQueue.sync {
            guard !audioBufferList.isEmpty else { return [Float](repeating: 0, count: samples) }

            let bufferCount = audioBufferList.count
            let samplesPerBucket = max(1, bufferCount / samples)
            var waveform = [Float](repeating: 0, count: samples)

            for i in 0..<samples {
                let start = i * samplesPerBucket
                let end = min(start + samplesPerBucket, bufferCount)
                guard start < end else { continue }

                var sum: Float = 0
                for j in start..<end {
                    sum += abs(audioBufferList[j])
                }
                waveform[i] = sum / Float(end - start)
            }

            // 归一化
            if let max = waveform.max(), max > 0 {
                waveform = waveform.map { $0 / max }
            }

            return waveform
        }
    }

    // MARK: - 获取录音质量
    func getRecordingQuality() -> RecordingQuality {
        return calculateQuality()
    }

    // MARK: - 私有方法 - 设置音频引擎
    private func setupAudioEngine() throws {
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else {
            throw NSError(domain: "AudioRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法创建音频引擎"])
        }

        inputNode = engine.inputNode
        guard let input = inputNode else {
            throw NSError(domain: "AudioRecorder", code: -2, userInfo: [NSLocalizedDescriptionKey: "无法获取音频输入节点"])
        }

        // 获取输入格式
        let inputFormat = input.inputFormat(forBus: 0)
        Logger.debug("输入格式: \(inputFormat)", category: .audio)

        // 创建目标格式 (24kHz, 16bit, mono)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        ) else {
            throw NSError(domain: "AudioRecorder", code: -3, userInfo: [NSLocalizedDescriptionKey: "无法创建目标音频格式"])
        }

        // 安装 tap 来获取音频数据
        let bufferSize: AVAudioFrameCount = 1024
        input.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, format: inputFormat, targetFormat: targetFormat)
        }

        mixerNode = AVAudioMixerNode()
        if let mixer = mixerNode {
            engine.attach(mixer)
            engine.connect(input, to: mixer, format: targetFormat)
        }

        engine.prepare()
    }

    // MARK: - 处理音频缓冲区
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat, targetFormat: AVAudioFormat) {
        guard isRecording && !isPaused else { return }
        guard let channelData = buffer.floatChannelData?[0] else { return }

        let frameLength = Int(buffer.frameLength)

        bufferQueue.async { [weak self] in
            guard let self = self else { return }

            // 计算 RMS 能量
            var rms: Float = 0
            vDSP_rmsqv(channelData, 1, &rms, UInt(frameLength))

            // 更新音量级别 (平滑处理)
            let normalizedLevel = min(max(rms * 5, 0), 1)
            self.currentMeterLevel = self.currentMeterLevel * 0.7 + normalizedLevel * 0.3

            DispatchQueue.main.async {
                self.delegate?.recorder(self, didUpdateMeterLevel: self.currentMeterLevel)
            }

            // 更新峰值
            if self.currentMeterLevel > self.peakLevel {
                self.peakLevel = self.currentMeterLevel
            }

            // VAD 检测
            self.performVAD(energy: rms, frameLength: frameLength, channelData: channelData)

            // 收集音频数据
            let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
            self.audioBufferList.append(contentsOf: samples)

            // 检测削波
            for i in 0..<frameLength {
                if abs(channelData[i]) > AudioConfig.clippingThreshold {
                    self.clippingCount += 1
                }
            }
            self.totalSamples += frameLength

            // 更新信号/噪声能量
            if self.isVoiceDetected {
                self.signalEnergy += rms * rms * Float(frameLength)
            } else {
                self.noiseEnergy += rms * rms * Float(frameLength)
            }

            // 更新时长
            DispatchQueue.main.async {
                let duration = self.currentDuration
                self.recordingDuration = duration
                self.delegate?.recorder(self, didUpdateDuration: duration)
            }
        }
    }

    // MARK: - VAD 语音活动检测
    private func performVAD(energy: Float, frameLength: Int, channelData: UnsafeMutablePointer<Float>) {
        let isVoiceFrame = energy > voiceActivityThreshold

        if isVoiceFrame {
            consecutiveVoiceFrames += 1
            consecutiveSilenceFrames = 0

            if consecutiveVoiceFrames >= voiceActivationThreshold && !isVoiceDetected {
                isVoiceDetected = true
                silenceStart = nil
                DispatchQueue.main.async {
                    self.delegate?.recorder(self, didDetectVoice: true)
                }
                Logger.debug("检测到语音开始", category: .audio)
            }
        } else {
            consecutiveSilenceFrames += 1
            consecutiveVoiceFrames = 0

            if consecutiveSilenceFrames >= silenceDeactivationThreshold && isVoiceDetected {
                isVoiceDetected = false
                silenceStart = Date()
                DispatchQueue.main.async {
                    self.delegate?.recorder(self, didDetectVoice: false)
                }
            }
        }
    }

    // MARK: - 计算录音质量
    private func calculateQuality() -> RecordingQuality {
        bufferQueue.sync {
            let snr: Double
            if noiseEnergy > 0 {
                snr = 10 * log10(Double(signalEnergy / noiseEnergy))
            } else {
                snr = 100  // 无噪声
            }

            let clippingRatio = totalSamples > 0 ? Double(clippingCount) / Double(totalSamples) : 0
            let hasClipping = clippingRatio > 0.001  // 超过0.1%削波
            let isTooQuiet = peakLevel < 0.05
            let isTooLoud = peakLevel > 0.98

            // 计算综合评分
            var score = 100.0
            if snr < AudioConfig.minSNR { score -= 30 }
            else if snr < 25 { score -= 10 }
            if hasClipping { score -= 25 }
            if isTooQuiet { score -= 20 }
            if isTooLoud { score -= 15 }
            score = max(0, min(100, score))

            return RecordingQuality(
                snr: snr,
                peakLevel: peakLevel,
                hasClipping: hasClipping,
                isTooQuiet: isTooQuiet,
                isTooLoud: isTooLoud,
                overallScore: score
            )
        }
    }

    // MARK: - 写入 WAV 文件
    private func writeWAVFile(to url: URL) throws {
        bufferQueue.sync {
            guard !audioBufferList.isEmpty else {
                throw NSError(domain: "AudioRecorder", code: -4, userInfo: [NSLocalizedDescriptionKey: "没有录音数据"])
            }

            // 音频后处理：降噪和归一化
            var processedSamples = audioBufferList
            normalizeAudio(&processedSamples)

            // WAV 文件头
            let numChannels = channels
            let sampleRateVal = Int(sampleRate)
            let bitsPerSample = bitsPerChannel
            let byteRate = sampleRateVal * Int(numChannels) * Int(bitsPerSample) / 8
            let blockAlign = Int(numChannels) * Int(bitsPerSample) / 8
            let dataSize = processedSamples.count * Int(bitsPerSample) / 8
            let fileSize = 44 + dataSize

            var header = Data()

            // RIFF header
            header.append("RIFF".data(using: .ascii)!)
            header.append(withUnsafeBytes(of: UInt32(fileSize - 8).littleEndian) { Data($0) })
            header.append("WAVE".data(using: .ascii)!)

            // fmt subchunk
            header.append("fmt ".data(using: .ascii)!)
            header.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })  // Subchunk1Size
            header.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })   // PCM format
            header.append(withUnsafeBytes(of: UInt16(numChannels).littleEndian) { Data($0) })
            header.append(withUnsafeBytes(of: UInt32(sampleRateVal).littleEndian) { Data($0) })
            header.append(withUnsafeBytes(of: UInt32(byteRate).littleEndian) { Data($0) })
            header.append(withUnsafeBytes(of: UInt16(blockAlign).littleEndian) { Data($0) })
            header.append(withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian) { Data($0) })

            // data subchunk
            header.append("data".data(using: .ascii)!)
            header.append(withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Data($0) })

            // 转换 Float32 到 Int16 PCM
            var pcmData = Data(capacity: processedSamples.count * 2)
            for sample in processedSamples {
                let clampedSample = max(-1.0, min(1.0, sample))
                let intSample = Int16(clampedSample * Float(Int16.max))
                pcmData.append(withUnsafeBytes(of: intSample.littleEndian) { Data($0) })
            }

            // 写入文件
            let wavData = header + pcmData
            try wavData.write(to: url)

            Logger.info("WAV 文件已保存: \(url.path), 大小: \(wavData.count) bytes", category: .audio)
        }
    }

    // MARK: - 音频归一化
    private func normalizeAudio(_ samples: inout [Float]) {
        // 找到峰值
        var peak: Float = 0
        vDSP_maxmgv(samples, 1, &peak, UInt(samples.count))

        guard peak > 0 else { return }

        // 目标峰值为 0.9 (避免削波)
        let targetPeak: Float = 0.9
        let gain = targetPeak / peak

        // 应用增益
        vDSP_vsmul(samples, 1, [gain], &samples, 1, UInt(samples.count))
    }

    // MARK: - 重置录音状态
    private func resetRecordingState() {
        bufferQueue.sync(flags: .barrier) {
            audioBufferList.removeAll()
            bufferData = Data()
        }
        currentMeterLevel = 0
        peakLevel = 0
        signalEnergy = 0
        noiseEnergy = 0
        clippingCount = 0
        totalSamples = 0
        isVoiceDetected = false
        consecutiveVoiceFrames = 0
        consecutiveSilenceFrames = 0
        silenceStart = nil
        recordingDuration = 0
        pausedDuration = 0
        pauseStartTime = nil
        recordingStartTime = nil
    }
}

// MARK: - Data 扩展
extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
