//
//  MamaBabaStoriesApp.swift
//  MamaBabaStories
//
//  爸爸妈妈讲故事 - App 入口
//  一款基于声音克隆的亲子讲故事应用
//

import SwiftUI
import AVFoundation
import MediaPlayer

@main
struct MamaBabaStoriesApp: App {
    // MARK: - App State
    @StateObject private var authService = AuthService.shared
    @StateObject private var playerViewModel = PlayerViewModel()
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var libraryViewModel = StoryLibraryViewModel()
    @StateObject private var voiceCloneViewModel = VoiceCloneViewModel()
    @StateObject private var aiCreateViewModel = AICreateViewModel()
    @StateObject private var profileViewModel = ProfileViewModel()
    @State private var isAppReady = false

    // MARK: - Init
    init() {
        configureAudioSession()
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !isAppReady {
                    // 启动画面
                    LaunchView()
                } else if authService.isAuthenticated {
                    MainTabView()
                        .transition(.opacity)
                } else {
                    LoginView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isAppReady)
            .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
            .environmentObject(authService)
            .environmentObject(playerViewModel)
            .environmentObject(homeViewModel)
            .environmentObject(libraryViewModel)
            .environmentObject(voiceCloneViewModel)
            .environmentObject(aiCreateViewModel)
            .environmentObject(profileViewModel)
            .task {
                // 启动时验证现有 token
                await authService.validateExistingToken()
                isAppReady = true
            }
            .onChange(of: authService.isAuthenticated) { _, authenticated in
                if authenticated {
                    Task {
                        await homeViewModel.loadData()
                        await libraryViewModel.loadData()
                        await voiceCloneViewModel.loadData()
                    }
                }
            }
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
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppColors.background)
        appearance.titleTextAttributes = [.foregroundColor: UIColor(AppColors.textPrimary)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(AppColors.textPrimary)]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance

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

// MARK: - 启动画面
struct LaunchView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [AppColors.warmYellow, AppColors.softOrange]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .scaleEffect(animate ? 1.0 : 0.8)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: animate)

                    Image(systemName: "book.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.white)
                }

                Text("爸爸妈妈讲故事")
                    .font(AppFonts.title(size: 24))
                    .foregroundColor(AppColors.textPrimary)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.softOrange))
            }
        }
        .onAppear {
            animate = true
        }
    }
}