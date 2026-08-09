//
//  StoryPlayerView.swift
//  MamaBabaStories
//
//  全屏故事播放器视图
//

import SwiftUI

struct StoryPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingSpeedMenu = false
    @State private var showingTimerMenu = false
    @State private var showingPlaylist = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // 背景渐变
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部导航
                topBar

                Spacer()

                // 封面
                coverSection
                    .padding(.bottom, 40)

                Spacer()

                // 进度条和控制
                controlsSection
                    .padding(.bottom, 40)

                // 底部操作
                bottomBar
            }
            .padding(.horizontal, Layout.horizontalPadding)
        }
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 150 {
                        playerVM.hideFullScreenPlayer()
                    }
                    withAnimation(.spring()) {
                        dragOffset = 0
                    }
                }
        )
        .confirmationDialog("播放速度", isPresented: $showingSpeedMenu, titleVisibility: .visible) {
            ForEach(AudioConfig.playbackSpeeds, id: \.self) { speed in
                Button(formatSpeed(speed)) {
                    playerVM.setPlaybackSpeed(speed)
                }
            }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog("睡眠定时", isPresented: $showingTimerMenu, titleVisibility: .visible) {
            ForEach(AudioConfig.sleepTimerOptions, id: \.self) { minutes in
                Button("\(minutes) 分钟") {
                    playerVM.setSleepTimer(minutes: minutes)
                }
            }
            if playerVM.isSleepTimerActive {
                Button("取消定时", role: .destructive) {
                    playerVM.cancelSleepTimer()
                }
            }
            Button("取消", role: .cancel) {}
        }
    }

    // MARK: - 背景渐变
    private var backgroundGradient: some View {
        ZStack {
            AppColors.background
            if let story = playerVM.currentStory {
                let colors = story.coverGradient?.compactMap { Color(hex: $0) } ?? [story.theme.color.opacity(0.3), AppColors.background]
                LinearGradient(
                    gradient: Gradient(colors: colors + [AppColors.background]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .opacity(0.6)
            }
        }
    }

    // MARK: - 顶部栏
    private var topBar: some View {
        HStack {
            Button(action: {
                playerVM.hideFullScreenPlayer()
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 40, height: 40)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(playerVM.currentStory?.voiceModelName ?? "爸爸妈妈讲故事")
                    .font(AppFonts.caption(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                Text("正在播放")
                    .font(AppFonts.caption(size: 10))
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()

            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - 封面
    private var coverSection: some View {
        VStack(spacing: 24) {
            if let story = playerVM.currentStory {
                StoryCoverView(story: story, size: CGSize(width: 280, height: 280))
                    .cornerRadius(Layout.largeCornerRadius)
                    .shadow(color: Color.black.opacity(0.15), radius: 30, x: 0, y: 15)
                    .scaleEffect(playerVM.isPlaying ? 1.0 : 0.9)
                    .animation(.easeInOut(duration: 0.3), value: playerVM.isPlaying)

                VStack(spacing: 8) {
                    Text(story.title)
                        .font(AppFonts.title(size: 24))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(story.voiceModelName ?? "爸爸妈妈讲故事")
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    // MARK: - 控制区
    private var controlsSection: some View {
        VStack(spacing: 24) {
            // 进度条
            VStack(spacing: 8) {
                Slider(value: Binding(
                    get: { playerVM.currentTime },
                    set: { playerVM.seek(to: $0) }
                ), in: 0...max(playerVM.duration, 1))
                    .tint(AppColors.softOrange)

                HStack {
                    Text(playerVM.formatTime(playerVM.currentTime))
                        .font(AppFonts.caption(size: 12))
                        .foregroundColor(AppColors.textTertiary)
                    Spacer()
                    Text(playerVM.formatTime(playerVM.duration))
                        .font(AppFonts.caption(size: 12))
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            // 播放控制按钮
            HStack(spacing: 40) {
                Button(action: { playerVM.playPrevious() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 28))
                        .foregroundColor(AppColors.textPrimary)
                }

                Button(action: { playerVM.seekBackward() }) {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 28))
                        .foregroundColor(AppColors.textPrimary)
                }

                Button(action: { playerVM.togglePlayPause() }) {
                    ZStack {
                        Circle()
                            .fill(AppColors.softOrange)
                            .frame(width: 72, height: 72)
                            .shadow(color: AppColors.softOrange.opacity(0.4), radius: 15, x: 0, y: 8)

                        Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.white)
                            .offset(x: playerVM.isPlaying ? 0 : 2)
                    }
                }

                Button(action: { playerVM.seekForward() }) {
                    Image(systemName: "goforward.30")
                        .font(.system(size: 28))
                        .foregroundColor(AppColors.textPrimary)
                }

                Button(action: { playerVM.playNext() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 28))
                        .foregroundColor(AppColors.textPrimary)
                }
            }
        }
    }

    // MARK: - 底部操作栏
    private var bottomBar: some View {
        HStack(spacing: 30) {
            Button(action: { showingSpeedMenu = true }) {
                VStack(spacing: 4) {
                    Text(formatSpeed(playerVM.playbackSpeed))
                        .font(AppFonts.caption(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                }
                .frame(width: 44, height: 44)
                .background(AppColors.surfaceVariant)
                .clipShape(Capsule())
            }

            Button(action: { playerVM.togglePlaybackMode() }) {
                Image(systemName: playerVM.playbackMode.icon)
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.textSecondary)
            }

            Button(action: { showingTimerMenu = true }) {
                Image(systemName: playerVM.isSleepTimerActive ? "timer" : "moon.zzz")
                    .font(.system(size: 20))
                    .foregroundColor(playerVM.isSleepTimerActive ? AppColors.softOrange : AppColors.textSecondary)
            }

            Button(action: {}) {
                Image(systemName: "heart")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.textSecondary)
            }

            Button(action: { showingPlaylist = true }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.bottom, 30)
        .sheet(isPresented: $showingPlaylist) {
            PlaylistView()
        }
    }

    private func formatSpeed(_ speed: Float) -> String {
        if speed == 1.0 { return "1.0x" }
        return String(format: "%.1fx", speed)
    }
}

// MARK: - 播放列表视图
struct PlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(playerVM.playlist.enumerated()), id: \.element.id) { index, story in
                    Button(action: {
                        playerVM.play(story: story, playlist: playerVM.playlist)
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            StoryCoverView(story: story, size: CGSize(width: 50, height: 50))
                                .cornerRadius(8)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(story.title)
                                    .font(AppFonts.body(size: 15, weight: index == playerVM.currentIndex ? .semibold : .regular))
                                    .foregroundColor(index == playerVM.currentIndex ? AppColors.softOrange : AppColors.textPrimary)
                                    .lineLimit(1)

                                Text(story.formattedDuration)
                                    .font(AppFonts.caption(size: 12))
                                    .foregroundColor(AppColors.textTertiary)
                            }

                            Spacer()

                            if index == playerVM.currentIndex && playerVM.isPlaying {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(AppColors.softOrange)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .listStyle(.plain)
            .navigationTitle("播放列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - 预览
struct StoryPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = PlayerViewModel()
        vm.currentStory = Story.mockStories[0]
        vm.isMiniPlayerVisible = true
        vm.isFullScreenPlayerPresented = true
        return StoryPlayerView()
            .environmentObject(vm)
    }
}
