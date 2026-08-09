//
//  PlayerViewModel.swift
//  MamaBabaStories
//
//  播放器 ViewModel - 管理播放状态和迷你播放器
//

import Foundation
import Combine
import SwiftUI

@MainActor
class PlayerViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentStory: Story?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackSpeed: Float = 1.0
    @Published var isMiniPlayerVisible = false
    @Published var isFullScreenPlayerPresented = false
    @Published var isBuffering = false
    @Published var playlist: [Story] = []
    @Published var currentIndex: Int = 0
    @Published var playbackMode: PlaybackMode = .sequential
    @Published var isSleepTimerActive = false
    @Published var sleepTimerMinutes: Int? = nil
    @Published var showingSpeedMenu = false
    @Published var showingTimerMenu = false
    @Published var isFavorited = false

    // MARK: - Properties
    private let audioPlayer = AudioPlayerManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init() {
        setupBindings()
        loadPreferences()
    }

    // MARK: - Bindings
    private func setupBindings() {
        // 监听音频播放器状态
        audioPlayer.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                self.isPlaying = state == .playing
                self.isBuffering = state == .buffering || state == .loading
            }
            .store(in: &cancellables)

        audioPlayer.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                self?.currentTime = time
            }
            .store(in: &cancellables)

        audioPlayer.$duration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                self?.duration = duration
            }
            .store(in: &cancellables)

        audioPlayer.$playbackSpeed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] speed in
                self?.playbackSpeed = speed
            }
            .store(in: &cancellables)

        audioPlayer.$isSleepTimerActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in
                self?.isSleepTimerActive = active
            }
            .store(in: &cancellables)
    }

    // MARK: - 播放控制
    func play(story: Story, playlist: [Story]? = nil) {
        currentStory = story
        isMiniPlayerVisible = true
        isFavorited = story.isFavorite

        if let playlist = playlist {
            self.playlist = playlist
            if let index = playlist.firstIndex(where: { $0.id == story.id }) {
                currentIndex = index
            }
        } else {
            self.playlist = [story]
            currentIndex = 0
        }

        audioPlayer.play(story: story, playlist: self.playlist)
    }

    func play() {
        audioPlayer.play()
    }

    func pause() {
        audioPlayer.pause()
    }

    func togglePlayPause() {
        audioPlayer.togglePlayPause()
    }

    func stop() {
        audioPlayer.stop()
        currentStory = nil
        isMiniPlayerVisible = false
        isFullScreenPlayerPresented = false
    }

    func seek(to time: TimeInterval) {
        audioPlayer.seek(to: time)
    }

    func seekBackward() {
        audioPlayer.seek(by: -15)
    }

    func seekForward() {
        audioPlayer.seek(by: 30)
    }

    func playNext() {
        audioPlayer.playNext()
        updateCurrentStoryFromPlaylist()
    }

    func playPrevious() {
        audioPlayer.playPrevious()
        updateCurrentStoryFromPlaylist()
    }

    private func updateCurrentStoryFromPlaylist() {
        if !playlist.isEmpty && currentIndex < playlist.count {
            currentStory = playlist[currentIndex]
            isFavorited = currentStory?.isFavorite ?? false
        }
    }

    // MARK: - 播放速度
    func setPlaybackSpeed(_ speed: Float) {
        playbackSpeed = speed
        audioPlayer.playbackSpeed = speed
        UserDefaults.standard.set(speed, forKey: UserDefaultsKeys.preferredPlaybackSpeed)
    }

    func cyclePlaybackSpeed() {
        let speeds = AudioConfig.playbackSpeeds
        if let currentIndex = speeds.firstIndex(of: playbackSpeed) {
            let nextIndex = (currentIndex + 1) % speeds.count
            setPlaybackSpeed(speeds[nextIndex])
        }
    }

    // MARK: - 睡眠定时器
    func setSleepTimer(minutes: Int) {
        audioPlayer.setSleepTimer(minutes: minutes)
        sleepTimerMinutes = minutes
        UserDefaults.standard.set(minutes, forKey: UserDefaultsKeys.sleepTimerMinutes)
    }

    func cancelSleepTimer() {
        audioPlayer.cancelSleepTimer()
        sleepTimerMinutes = nil
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.sleepTimerMinutes)
    }

    // MARK: - 播放模式
    func togglePlaybackMode() {
        switch playbackMode {
        case .sequential: playbackMode = .listLoop
        case .listLoop: playbackMode = .singleLoop
        case .singleLoop: playbackMode = .sequential
        }
        audioPlayer.playbackMode = playbackMode
    }

    // MARK: - 全屏播放器
    func showFullScreenPlayer() {
        isFullScreenPlayerPresented = true
    }

    func hideFullScreenPlayer() {
        isFullScreenPlayerPresented = false
    }

    // MARK: - 格式化
    func formatTime(_ time: TimeInterval) -> String {
        return audioPlayer.formatTime(time)
    }

    // MARK: - 进度
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    // MARK: - 偏好设置
    private func loadPreferences() {
        let savedSpeed = UserDefaults.standard.float(forKey: UserDefaultsKeys.preferredPlaybackSpeed)
        if savedSpeed > 0 {
            playbackSpeed = savedSpeed
            audioPlayer.playbackSpeed = savedSpeed
        }
    }
}
