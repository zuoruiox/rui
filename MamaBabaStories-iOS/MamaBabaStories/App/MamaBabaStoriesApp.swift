//
//  MamaBabaStoriesApp.swift
//  MamaBabaStories
//
//  爸爸妈妈讲故事 - App 入口
//  一款基于声音克隆的亲子讲故事应用
//

import SwiftUI
import AVFoundation

@main
struct MamaBabaStoriesApp: App {
    // MARK: - App State
    @StateObject private var playerViewModel = PlayerViewModel()
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var libraryViewModel = StoryLibraryViewModel()
    @StateObject private var voiceCloneViewModel = VoiceCloneViewModel()
    @StateObject private var aiCreateViewModel = AICreateViewModel()
    @StateObject private var profileViewModel = ProfileViewModel()

    // MARK: - Init
    init() {
        configureAudioSession()
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(playerViewModel)
                .environmentObject(homeViewModel)
                .environmentObject(libraryViewModel)
                .environmentObject(voiceCloneViewModel)
                .environmentObject(aiCreateViewModel)
                .environmentObject(profileViewModel)
                .onAppear {
                    setupRemoteCommandCenter()
                }
        }
    }

    // MARK: - Audio Session Configuration
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord,
                                    mode: .default,
                                    options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try session.setActive(true)
        } catch {
            Logger.error("音频会话配置失败: \(error.localizedDescription)", category: .audio)
        }
    }

    // MARK: - UI Appearance
    private func configureAppearance() {
        // 导航栏外观
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppColors.background)
        appearance.titleTextAttributes = [.foregroundColor: UIColor(AppColors.textPrimary)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(AppColors.textPrimary)]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance

        // TabBar 外观
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(AppColors.surface)

        UITabBar.appearance().standardAppearance = tabAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        }
    }

    // MARK: - Remote Command Center
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak playerViewModel] _ in
            playerViewModel?.play()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak playerViewModel] _ in
            playerViewModel?.pause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak playerViewModel] _ in
            playerViewModel?.togglePlayPause()
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak playerViewModel] _ in
            playerViewModel?.playNext()
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak playerViewModel] _ in
            playerViewModel?.playPrevious()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak playerViewModel] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            playerViewModel?.seek(to: event.positionTime)
            return .success
        }
    }
}

// MARK: - MediaPlayer Import
import MediaPlayer
