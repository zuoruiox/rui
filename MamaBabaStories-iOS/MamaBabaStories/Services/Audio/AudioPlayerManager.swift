//
//  AudioPlayerManager.swift
//  MamaBabaStories
//
//  音频播放管理器 - 基于 AVPlayer
//  支持后台播放、锁屏控制、睡眠定时、播放速度、下载
//

import Foundation
import AVFoundation
import MediaPlayer
import Combine

// MARK: - 播放状态
enum PlaybackState: Equatable {
    case idle
    case loading
    case readyToPlay
    case playing
    case paused
    case buffering
    case finished
    case failed(Error)

    static func == (lhs: PlaybackState, rhs: PlaybackState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.readyToPlay, .readyToPlay),
             (.playing, .playing), (.paused, .paused), (.buffering, .buffering),
             (.finished, .finished):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }

    var isPlaying: Bool {
        self == .playing
    }

    var isActive: Bool {
        switch self {
        case .playing, .paused, .loading, .buffering, .readyToPlay:
            return true
        default:
            return false
        }
    }
}

// MARK: - 播放模式
enum PlaybackMode: String, CaseIterable {
    case sequential = "顺序播放"
    case singleLoop = "单曲循环"
    case listLoop = "列表循环"

    var icon: String {
        switch self {
        case .sequential: return "arrow.forward"
        case .singleLoop: return "repeat.1"
        case .listLoop: return "repeat"
        }
    }
}

// MARK: - AudioPlayerManager
class AudioPlayerManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var state: PlaybackState = .idle
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var bufferedTime: TimeInterval = 0
    @Published var playbackSpeed: Float = AudioConfig.defaultPlaybackSpeed {
        didSet {
            player?.rate = playbackSpeed
            UserDefaults.standard.set(playbackSpeed, forKey: UserDefaultsKeys.preferredPlaybackSpeed)
        }
    }
    @Published var playbackMode: PlaybackMode = .sequential
    @Published var isSleepTimerActive = false
    @Published private(set) var sleepTimerRemaining: TimeInterval = 0

    // MARK: - Properties
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var itemEndObserver: NSObjectProtocol?
    private var itemFailedObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?

    // 当前播放的故事
    private(set) var currentStory: Story?
    private var playlist: [Story] = []
    private var currentIndex: Int = 0

    // 睡眠定时器
    private var sleepTimer: Timer?
    private var sleepTimerEndDate: Date?
    private var fadeOutTimer: Timer?
    private var fadeOutVolume: Float = 1.0

    // 下载管理
    private var downloadSession: URLSession?
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private let downloadsDirectory: URL

    // 后台任务
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid

    // 音量淡入淡出
    private var originalVolume: Float = 1.0

    // MARK: - Singleton
    static let shared = AudioPlayerManager()

    // MARK: - Init
    override init() {
        // 创建下载目录
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        downloadsDirectory = docsDir.appendingPathComponent("Downloads", isDirectory: true)
        super.init()

        try? FileManager.default.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)

        // 恢复用户偏好
        playbackSpeed = UserDefaults.standard.float(forKey: UserDefaultsKeys.preferredPlaybackSpeed)
        if playbackSpeed == 0 { playbackSpeed = 1.0 }

        setupAudioSession()
        setupObservers()
        setupDownloadSession()
    }

    deinit {
        removeObservers()
        sleepTimer?.invalidate()
        fadeOutTimer?.invalidate()
    }

    // MARK: - 音频会话配置
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.allowBluetooth, .allowAirPlay])
            try session.setActive(true)
        } catch {
            Logger.error("播放音频会话配置失败: \(error)", category: .audio)
        }
    }

    // MARK: - 观察者设置
    private func setupObservers() {
        // 播放结束通知
        itemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let item = notification.object as? AVPlayerItem,
                  item == self.playerItem else { return }
            self.handlePlaybackFinished()
        }

        // 播放失败通知
        itemFailedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            self.state = .failed(error ?? NSError(domain: "AudioPlayer", code: -1))
            Logger.error("播放失败: \(error?.localizedDescription ?? "未知错误")", category: .audio)
        }

        // 中断处理
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }

        // 音频路由变化（耳机拔出等）
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
    }

    private func removeObservers() {
        if let observer = itemEndObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = itemFailedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
    }

    // MARK: - 中断处理
    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            if state == .playing {
                pause()
            }
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                play()
            }
        @unknown default:
            break
        }
    }

    // MARK: - 路由变化处理
    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .oldDeviceUnavailable:
            // 耳机拔出，暂停播放
            if state == .playing {
                pause()
            }
        default:
            break
        }
    }

    // MARK: - 下载会话设置
    private func setupDownloadSession() {
        let config = URLSessionConfiguration.background(withIdentifier: "com.mamababa.downloads")
        config.isDiscretionary = true
        config.sessionSendsLaunchEvents = true
        downloadSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    // MARK: - 播放控制
    func play(story: Story, playlist: [Story]? = nil) {
        if let playlist = playlist {
            self.playlist = playlist
            if let index = playlist.firstIndex(where: { $0.id == story.id }) {
                currentIndex = index
            }
        } else {
            self.playlist = [story]
            currentIndex = 0
        }

        currentStory = story
        setupPlayerItem(for: story)
    }

    func play() {
        guard let player = player else { return }
        player.rate = playbackSpeed
        state = .playing
        updateNowPlayingInfo()
        beginBackgroundTask()
    }

    func pause() {
        player?.pause()
        state = .paused
        updateNowPlayingInfo()
        endBackgroundTask()
    }

    func togglePlayPause() {
        if state == .playing {
            pause()
        } else {
            play()
        }
    }

    func stop() {
        player?.pause()
        player?.seek(to: .zero)
        player = nil
        playerItem = nil
        currentStory = nil
        currentTime = 0
        duration = 0
        state = .idle
        removeNowPlayingInfo()
        cancelSleepTimer()
        endBackgroundTask()
    }

    func seek(to time: TimeInterval) {
        guard let player = player else { return }
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            self?.currentTime = time
            self?.updateNowPlayingInfo()
        }
    }

    func seek(by delta: TimeInterval) {
        let newTime = max(0, min(currentTime + delta, duration))
        seek(to: newTime)
    }

    // MARK: - 上一首/下一首
    func playNext() {
        guard !playlist.isEmpty else { return }

        switch playbackMode {
        case .singleLoop:
            seek(to: 0)
            play()
        case .listLoop:
            currentIndex = (currentIndex + 1) % playlist.count
            play(story: playlist[currentIndex])
        case .sequential:
            if currentIndex < playlist.count - 1 {
                currentIndex += 1
                play(story: playlist[currentIndex])
            } else {
                // 播放列表结束
                state = .finished
            }
        }
    }

    func playPrevious() {
        guard !playlist.isEmpty else { return }

        if currentTime > 3 {
            // 如果播放超过3秒，回到开头
            seek(to: 0)
        } else {
            switch playbackMode {
            case .singleLoop:
                seek(to: 0)
            case .listLoop:
                currentIndex = (currentIndex - 1 + playlist.count) % playlist.count
                play(story: playlist[currentIndex])
            case .sequential:
                if currentIndex > 0 {
                    currentIndex -= 1
                    play(story: playlist[currentIndex])
                } else {
                    seek(to: 0)
                }
            }
        }
    }

    // MARK: - 设置播放项
    private func setupPlayerItem(for story: Story) {
        // 清理旧的观察者
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        playerItem?.removeObserver(self, forKeyPath: "status")
        playerItem?.removeObserver(self, forKeyPath: "loadedTimeRanges")

        // 确定音频 URL - 优先级：本地路径 > 已下载文件 > 远程URL
        var audioURL: URL?

        // 1. 优先使用 localAudioPath
        if let localPath = story.localAudioPath, !localPath.isEmpty {
            let localURL = URL(fileURLWithPath: localPath)
            if FileManager.default.fileExists(atPath: localPath) {
                audioURL = localURL
            }
        }

        // 2. 检查下载目录
        if audioURL == nil && isDownloaded(storyId: story.id) {
            audioURL = localFileURL(for: story.id)
        }

        // 3. 使用远程 audioURL
        if audioURL == nil, let urlString = story.audioURL, !urlString.isEmpty {
            audioURL = resolveAudioURL(urlString)
        }

        // 如果没有有效音频，生成测试音频用于演示
        if audioURL == nil {
            audioURL = generateTestAudio(for: story)
        }

        guard let url = audioURL else {
            state = .failed(NSError(domain: "AudioPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "音频地址无效"]))
            return
        }

        Logger.info("播放音频: \(url.absoluteString), isLocal: \(url.isFileURL)", category: .audio)
        state = .loading

        // 创建 AVPlayerItem
        let asset = AVURLAsset(url: url)
        playerItem = AVPlayerItem(asset: asset)

        if player == nil {
            player = AVPlayer()
        }

        player?.replaceCurrentItem(with: playerItem)
        player?.volume = 1.0
        player?.rate = playbackSpeed

        // 添加 KVO 观察者
        playerItem?.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
        playerItem?.addObserver(self, forKeyPath: "loadedTimeRanges", options: [.new], context: nil)

        // 添加时间观察者
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            self.updateSleepTimer()
        }
    }

    // MARK: - 解析音频URL（处理各种路径格式）
    private func resolveAudioURL(_ urlString: String) -> URL? {
        // 完整HTTP URL
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return URL(string: urlString)
        }

        let baseURLString = APIConfig.baseURL

        // 绝对路径（以 / 开头，如 /api/files/audio/xxx 或 /files/audio/xxx）
        if urlString.hasPrefix("/") {
            // 从 baseURL 中提取 scheme://host:port
            if let baseURL = URL(string: baseURLString), let host = baseURL.host {
                let scheme = baseURL.scheme ?? "http"
                let portPart = baseURL.port != nil ? ":\(baseURL.port!)" : ""
                // 如果路径以 /api/ 开头且 baseURL 已经包含 /api，避免重复
                var fullPath = urlString
                if urlString.hasPrefix("/api/") && baseURLString.contains("/api") {
                    // baseURL 已经是 http://host:port/api，urlString 是 /api/xxx，需要去掉 /api 前缀
                    fullPath = String(urlString.dropFirst(4)) // 去掉 "/api"
                }
                return URL(string: "\(scheme)://\(host)\(portPart)\(fullPath)")
            }
            return URL(string: baseURLString + urlString)
        }

        // 相对路径，拼接 baseURL
        let separator = baseURLString.hasSuffix("/") ? "" : "/"
        return URL(string: baseURLString + separator + urlString)
    }

    // MARK: - KVO
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            guard let item = object as? AVPlayerItem else { return }
            DispatchQueue.main.async { [weak self] in
                switch item.status {
                case .readyToPlay:
                    self?.duration = item.duration.seconds
                    self?.state = .readyToPlay
                    self?.play()
                    self?.updateNowPlayingInfo()
                case .failed:
                    self?.state = .failed(item.error ?? NSError(domain: "AudioPlayer", code: -2))
                    Logger.error("Player item failed: \(item.error?.localizedDescription ?? "")", category: .audio)
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        } else if keyPath == "loadedTimeRanges" {
            guard let item = object as? AVPlayerItem,
                  let timeRange = item.loadedTimeRanges.first?.timeRangeValue else { return }
            DispatchQueue.main.async { [weak self] in
                self?.bufferedTime = timeRange.start.seconds + timeRange.duration.seconds
            }
        }
    }

    // MARK: - 播放结束处理
    private func handlePlaybackFinished() {
        switch playbackMode {
        case .singleLoop:
            seek(to: 0)
            play()
        case .listLoop:
            playNext()
        case .sequential:
            if currentIndex < playlist.count - 1 {
                playNext()
            } else {
                state = .finished
                endBackgroundTask()
            }
        }
    }

    // MARK: - 睡眠定时器
    func setSleepTimer(minutes: Int) {
        cancelSleepTimer()
        isSleepTimerActive = true
        sleepTimerRemaining = TimeInterval(minutes * 60)
        sleepTimerEndDate = Date().addingTimeInterval(TimeInterval(minutes * 60))

        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateSleepTimer()
        }
    }

    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        fadeOutTimer?.invalidate()
        fadeOutTimer = nil
        isSleepTimerActive = false
        sleepTimerRemaining = 0
        sleepTimerEndDate = nil
        player?.volume = originalVolume
    }

    private func updateSleepTimer() {
        guard isSleepTimerActive, let endDate = sleepTimerEndDate else { return }

        sleepTimerRemaining = max(0, endDate.timeIntervalSinceNow)

        // 最后30秒开始淡出
        if sleepTimerRemaining <= 30 && sleepTimerRemaining > 0 {
            let fadeProgress = 1.0 - (sleepTimerRemaining / 30.0)
            player?.volume = originalVolume * (1.0 - Float(fadeProgress))
        }

        if sleepTimerRemaining <= 0 {
            pause()
            cancelSleepTimer()
        }
    }

    // MARK: - 后台任务
    private func beginBackgroundTask() {
        guard backgroundTaskId == .invalid else { return }
        backgroundTaskId = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        if backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }
    }

    // MARK: - Now Playing Info
    private func updateNowPlayingInfo() {
        guard let story = currentStory else { return }

        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = story.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = story.voiceModelName ?? "爸爸妈妈讲故事"
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "故事集"
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = state == .playing ? playbackSpeed : 0

        // 设置封面图
        if let emoji = story.coverEmoji as NSString? {
            let size = CGSize(width: 300, height: 300)
            UIGraphicsBeginImageContextWithOptions(size, false, 0)
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            let font = UIFont.systemFont(ofSize: 200)
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let textSize = emoji.size(withAttributes: attributes)
            let rect = CGRect(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2, width: textSize.width, height: textSize.height)
            emoji.draw(in: rect, withAttributes: attributes)
            if let image = UIGraphicsGetImageFromCurrentImageContext() {
                let artwork = MPMediaItemArtwork(boundsSize: size) { _ in image }
                nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            }
            UIGraphicsEndImageContext()
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func removeNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - 下载管理
    func downloadStory(_ story: Story, progressHandler: ((Double) -> Void)? = nil) async throws {
        guard let audioURLString = story.audioURL, !audioURLString.isEmpty else {
            throw NSError(domain: "AudioPlayer", code: -3, userInfo: [NSLocalizedDescriptionKey: "音频URL无效"])
        }

        // 使用统一的URL解析方法
        guard let url = resolveAudioURL(audioURLString) else {
            throw NSError(domain: "AudioPlayer", code: -3, userInfo: [NSLocalizedDescriptionKey: "音频URL无效"])
        }

        let destinationURL = localFileURL(for: story.id)

        Logger.info("开始下载音频: \(url.absoluteString)", category: .audio)

        // 使用 URLSession 下载（带进度）
        let downloadTask = downloadSession?.downloadTask(with: url)
        downloadTask?.taskDescription = story.id
        downloadTask?.resume()

        // 简单的进度轮询（实际项目可使用 delegate 模式）
        var lastProgress: Double = 0
        let startTime = Date()
        while let task = downloadTask, task.state == .running {
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms
            let expectedToReceive = max(task.countOfBytesExpectedToReceive, 1)
            let progress = Double(task.countOfBytesReceived) / Double(expectedToReceive)
            if abs(progress - lastProgress) > 0.01 {
                progressHandler?(progress)
                lastProgress = progress
            }
            // 超时保护 5 分钟
            if Date().timeIntervalSince(startTime) > 300 {
                task.cancel()
                throw NSError(domain: "AudioPlayer", code: -4, userInfo: [NSLocalizedDescriptionKey: "下载超时"])
            }
        }

        // 检查结果
        if let error = downloadTask?.error {
            throw error
        }

        // 文件已在 delegate 中移动，确认存在
        if !FileManager.default.fileExists(atPath: destinationURL.path) {
            throw NSError(domain: "AudioPlayer", code: -5, userInfo: [NSLocalizedDescriptionKey: "下载文件未找到"])
        }

        progressHandler?(1.0)
        Logger.info("故事下载完成: \(story.title) -> \(destinationURL.path)", category: .audio)
    }

    func isDownloaded(storyId: String) -> Bool {
        return FileManager.default.fileExists(atPath: localFileURL(for: storyId).path)
    }

    func deleteDownload(storyId: String) throws {
        let url = localFileURL(for: storyId)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    func localFileURL(for storyId: String) -> URL {
        return downloadsDirectory.appendingPathComponent("\(storyId).mp3")
    }

    // MARK: - 格式化时间
    func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "00:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

    // MARK: - 生成测试音频
    /// 为没有有效音频的故事生成一段测试音频（正弦波音调），用于演示播放功能
    private func generateTestAudio(for story: Story) -> URL? {
        let tempDir = NSTemporaryDirectory()
        let fileName = "test_\(story.id).wav"
        let fileURL = URL(fileURLWithPath: tempDir).appendingPathComponent(fileName)

        // 如果已存在，直接返回
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        let sampleRate: Double = 22050
        let duration = min(story.duration, 30)  // 最多生成30秒测试音频
        let totalSamples = Int(sampleRate * duration)

        // 根据故事ID选择不同的音调频率
        let hash = abs(story.id.hashValue)
        let frequencies: [Double] = [261.63, 293.66, 329.63, 349.23, 392.00, 440.00, 493.88, 523.25]
        let freq = frequencies[hash % frequencies.count]
        let freq2 = frequencies[(hash / 7) % frequencies.count]

        // 生成 WAV 文件
        var wavData = Data()

        // WAV header
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate * Double(numChannels) * Double(bitsPerSample) / 8)
        let blockAlign = UInt16(numChannels * bitsPerSample / 8)
        let dataSize = UInt32(totalSamples * Int(bitsPerSample) / 8)
        let fileSize = UInt32(44 + dataSize)

        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: (fileSize - 8).littleEndian) { Data($0) })
        wavData.append("WAVE".data(using: .ascii)!)
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })  // PCM
        wavData.append(withUnsafeBytes(of: numChannels.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        wavData.append("data".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })

        // 生成带包络的正弦波（避免爆音）
        let envelopeSamples = Int(sampleRate * 0.05)  // 50ms 淡入淡出
        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate
            // 两个频率叠加，更悦耳
            var sample = sin(2 * .pi * freq * t) * 0.3 + sin(2 * .pi * freq2 * t) * 0.2

            // 应用包络
            if i < envelopeSamples {
                sample *= Double(i) / Double(envelopeSamples)
            } else if i > totalSamples - envelopeSamples {
                sample *= Double(totalSamples - i) / Double(envelopeSamples)
            }

            let intSample = Int16(max(-1.0, min(1.0, sample)) * Double(Int16.max))
            wavData.append(withUnsafeBytes(of: intSample.littleEndian) { Data($0) })
        }

        do {
            try wavData.write(to: fileURL)
            Logger.info("已生成测试音频: \(fileURL.lastPathComponent), 时长: \(duration)s", category: .audio)
            return fileURL
        } catch {
            Logger.error("生成测试音频失败: \(error)", category: .audio)
            return nil
        }
    }

// MARK: - URLSessionDownloadDelegate
extension AudioPlayerManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let storyId = downloadTask.taskDescription else { return }
        let destinationURL = localFileURL(for: storyId)
        try? FileManager.default.moveItem(at: location, to: destinationURL)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            // 可以通过通知或回调传递进度
            NotificationCenter.default.post(name: NSNotification.Name("DownloadProgress"), object: nil, userInfo: [
                "storyId": downloadTask.taskDescription ?? "",
                "progress": progress
            ])
        }
    }
}
