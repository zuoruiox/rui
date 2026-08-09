//
//  MainTabView.swift
//  MamaBabaStories
//
//  主标签栏视图 - 包含迷你播放器
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                        Text("首页")
                    }
                    .tag(0)

                StoryLibraryView()
                    .tabItem {
                        Image(systemName: selectedTab == 1 ? "book.fill" : "book")
                        Text("故事库")
                    }
                    .tag(1)

                AICreateView()
                    .tabItem {
                        Image(systemName: selectedTab == 2 ? "sparkles" : "sparkles")
                        Text("AI创作")
                    }
                    .tag(2)

                VoiceCloneView()
                    .tabItem {
                        Image(systemName: selectedTab == 3 ? "mic.fill" : "mic")
                        Text("声音")
                    }
                    .tag(3)

                ProfileView()
                    .tabItem {
                        Image(systemName: selectedTab == 4 ? "person.fill" : "person")
                        Text("我的")
                    }
                    .tag(4)
            }
            .tint(AppColors.softOrange)

            // 迷你播放器
            if playerVM.isMiniPlayerVisible && !playerVM.isFullScreenPlayerPresented {
                VStack(spacing: 0) {
                    Spacer()
                    MiniPlayerView()
                        .padding(.bottom, 49) // TabBar 高度
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .ignoresSafeArea(.keyboard)
            }
        }
        .fullScreenCover(isPresented: $playerVM.isFullScreenPlayerPresented) {
            StoryPlayerView()
        }
        .animation(.easeInOut(duration: 0.3), value: playerVM.isMiniPlayerVisible)
    }
}

// MARK: - 迷你播放器
struct MiniPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        Button(action: {
            playerVM.showFullScreenPlayer()
        }) {
            HStack(spacing: 12) {
                // 封面
                if let story = playerVM.currentStory {
                    StoryCoverView(story: story, size: CGSize(width: 44, height: 44))
                        .cornerRadius(8)
                }

                // 信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(playerVM.currentStory?.title ?? "未知故事")
                        .font(AppFonts.body(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    Text(playerVM.currentStory?.voiceModelName ?? "爸爸妈妈讲故事")
                        .font(AppFonts.caption(size: 11))
                        .foregroundColor(AppColors.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                // 进度条
                ProgressView(value: playerVM.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: AppColors.softOrange))
                    .frame(width: 60)

                // 播放/暂停按钮
                Button(action: {
                    playerVM.togglePlayPause()
                }) {
                    Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.softOrange)
                        .frame(width: 40, height: 40)
                }

                // 关闭按钮
                Button(action: {
                    playerVM.stop()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 28, height: 28)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Rectangle()
                            .fill(AppColors.surface.opacity(0.8))
                    )
            )
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color.gray.opacity(0.2)),
                alignment: .top
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 预览
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(PlayerViewModel())
            .environmentObject(HomeViewModel())
            .environmentObject(StoryLibraryViewModel())
            .environmentObject(VoiceCloneViewModel())
            .environmentObject(AICreateViewModel())
            .environmentObject(ProfileViewModel())
    }
}
