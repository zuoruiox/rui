//
//  HomeView.swift
//  MamaBabaStories
//
//  首页视图
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var homeVM: HomeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var voiceVM: VoiceCloneViewModel
    @State private var showingSearch = false
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // 顶部问候区
                    headerSection

                    // 快捷操作
                    quickActionsSection

                    // 继续收听
                    if let story = homeVM.featuredStories.first {
                        continueListeningSection(story: story)
                    }

                    // 精选故事
                    featuredStoriesSection

                    // 声音选择
                    voiceSelectionSection

                    // 主题分类
                    themeSection

                    // 最近播放
                    recentStoriesSection
                }
                .padding(.bottom, playerVM.isMiniPlayerVisible ? 80 : 20)
            }
            .background(AppColors.background)
            .refreshable {
                await homeVM.refresh()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(AppInfo.appName)
                        .font(AppFonts.title(size: 22))
                        .foregroundColor(AppColors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSearch = true }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingSearch) {
            SearchView()
        }
    }

    // MARK: - 头部问候
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: homeVM.greetingIcon)
                        .font(.system(size: 22))
                        .foregroundColor(AppColors.softOrange)
                    Text(homeVM.greeting)
                        .font(AppFonts.title(size: 26))
                        .foregroundColor(AppColors.textPrimary)
                }

                if let child = homeVM.currentChild {
                    Text("今天给\(child.name)讲什么故事呢？")
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.textSecondary)
                } else {
                    Text("今天讲什么故事呢？")
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            Spacer()

            // 头像
            Button(action: {}) {
                if let child = homeVM.currentChild {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.warmYellow)
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.top, 8)
    }

    // MARK: - 快捷操作
    private var quickActionsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(homeVM.quickActions) { action in
                    QuickActionCard(action: action)
                }
            }
            .padding(.horizontal, Layout.horizontalPadding)
        }
    }

    // MARK: - 继续收听
    private func continueListeningSection(story: Story) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("继续收听")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
            }

            Button(action: {
                playerVM.play(story: story, playlist: homeVM.featuredStories)
            }) {
                HStack(spacing: 14) {
                    ZStack {
                        StoryCoverView(story: story, size: CGSize(width: 70, height: 70))
                            .cornerRadius(12)

                        Circle()
                            .fill(.white.opacity(0.9))
                            .frame(width: 30, height: 30)
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.softOrange)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(story.title)
                            .font(AppFonts.headline(size: 16))
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)

                        Text(story.voiceModelName ?? "爸爸妈妈讲故事")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.textSecondary)

                        ProgressView(value: 0.3)
                            .progressViewStyle(LinearProgressViewStyle(tint: AppColors.softOrange))
                            .frame(width: 150)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("30%")
                            .font(AppFonts.caption(size: 12, weight: .medium))
                            .foregroundColor(AppColors.softOrange)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: Layout.cornerRadius)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [AppColors.warmYellow.opacity(0.2), AppColors.softOrange.opacity(0.1)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, Layout.horizontalPadding)
    }

    // MARK: - 精选故事
    private var featuredStoriesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(AppColors.warmYellow)
                Text("精选推荐")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Button("查看全部") {}
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.softOrange)
            }
            .padding(.horizontal, Layout.horizontalPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(homeVM.featuredStories) { story in
                        FeaturedStoryCard(story: story, onTap: {
                            playerVM.play(story: story, playlist: homeVM.featuredStories)
                        }, onPlay: {
                            playerVM.play(story: story, playlist: homeVM.featuredStories)
                        })
                    }
                }
                .padding(.horizontal, Layout.horizontalPadding)
            }
        }
    }

    // MARK: - 声音选择
    private var voiceSelectionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundColor(AppColors.softPink)
                Text("选择声音")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Button("管理") {}
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.softOrange)
            }
            .padding(.horizontal, Layout.horizontalPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(homeVM.voiceModels) { model in
                        VoiceModelCard(voiceModel: model, isSelected: model.isDefault)
                    }
                    AddVoiceCard {}
                }
                .padding(.horizontal, Layout.horizontalPadding)
            }
        }
    }

    // MARK: - 主题分类
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "books.vertical.fill")
                    .foregroundColor(AppColors.gentleBlue)
                Text("故事主题")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding(.horizontal, Layout.horizontalPadding)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(StoryTheme.allCases) { theme in
                    ThemeCard(theme: theme)
                }
            }
            .padding(.horizontal, Layout.horizontalPadding)
        }
    }

    // MARK: - 最近播放
    private var recentStoriesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(AppColors.softOrange)
                Text("最近播放")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, Layout.horizontalPadding)

            VStack(spacing: 10) {
                ForEach(homeVM.recentStories.prefix(4)) { story in
                    StoryCard(story: story, onTap: {
                        playerVM.play(story: story, playlist: homeVM.recentStories)
                    }, onPlay: {
                        playerVM.play(story: story, playlist: homeVM.recentStories)
                    })
                }
            }
            .padding(.horizontal, Layout.horizontalPadding)
        }
    }
}

// MARK: - 快捷操作卡片
struct QuickActionCard: View {
    let action: QuickAction
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        Button(action: {
            if let story = action.story {
                playerVM.play(story: story)
            }
        }) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(action.color.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: action.icon)
                        .font(.system(size: 20))
                        .foregroundColor(action.color)
                }

                Text(action.title)
                    .font(AppFonts.body(size: 15, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Layout.cornerRadius)
                    .fill(AppColors.surface)
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 主题卡片
struct ThemeCard: View {
    let theme: StoryTheme

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(theme.color.opacity(0.2))
                    .frame(width: 60, height: 60)
                Image(systemName: theme.icon)
                    .font(.system(size: 24))
                    .foregroundColor(theme.color)
            }

            Text(theme.rawValue)
                .font(AppFonts.caption(size: 12, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
        }
    }
}

// MARK: - 搜索视图
struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            VStack {
                if searchText.isEmpty {
                    // 热门搜索
                    VStack(alignment: .leading, spacing: 16) {
                        Text("热门搜索")
                            .font(AppFonts.headline())
                            .padding(.horizontal)

                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                                ForEach(["小兔子", "睡前故事", "恐龙", "公主", "超级英雄", "汽车", "魔法", "动物"], id: \.self) { tag in
                                    TagButton(title: tag, icon: nil, isSelected: false) {}
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                } else {
                    Text("搜索结果")
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
            }
            .navigationTitle("搜索故事")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索故事、角色、主题")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 预览
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(HomeViewModel())
            .environmentObject(PlayerViewModel())
            .environmentObject(VoiceCloneViewModel())
    }
}
