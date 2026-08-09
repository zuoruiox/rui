//
//  StoryLibraryView.swift
//  MamaBabaStories
//
//  故事库视图
//

import SwiftUI

struct StoryLibraryView: View {
    @EnvironmentObject var libraryVM: StoryLibraryViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @State private var selectedSegment = 0
    @State private var showingFilter = false

    private let segments = ["全部", "收藏", "已下载"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索栏
                searchBar
                    .padding(.horizontal, Layout.horizontalPadding)
                    .padding(.top, 8)

                // 分段选择器
                segmentPicker
                    .padding(.horizontal, Layout.horizontalPadding)
                    .padding(.top, 12)

                // 主题筛选
                themeFilterBar
                    .padding(.top, 12)

                // 故事列表
                storyList
            }
            .background(AppColors.background)
            .navigationTitle("故事库")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingFilter = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 18))
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingFilter) {
            FilterView()
        }
    }

    // MARK: - 搜索栏
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.textTertiary)
                .font(.system(size: 16))

            TextField("搜索故事、角色...", text: $libraryVM.searchText)
                .font(AppFonts.body())
                .foregroundColor(AppColors.textPrimary)

            if !libraryVM.searchText.isEmpty {
                Button(action: { libraryVM.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textTertiary)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.surface)
                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
        )
    }

    // MARK: - 分段选择器
    private var segmentPicker: some View {
        HStack(spacing: 0) {
            ForEach(0..<segments.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSegment = index
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(segments[index])
                            .font(AppFonts.body(size: 15, weight: selectedSegment == index ? .semibold : .regular))
                            .foregroundColor(selectedSegment == index ? AppColors.softOrange : AppColors.textSecondary)

                        Rectangle()
                            .fill(selectedSegment == index ? AppColors.softOrange : Color.clear)
                            .frame(height: 3)
                            .cornerRadius(1.5)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 主题筛选
    private var themeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TagButton(title: "全部", icon: nil, isSelected: libraryVM.selectedTheme == nil) {
                    libraryVM.selectTheme(nil)
                }

                ForEach(StoryTheme.allCases) { theme in
                    TagButton(title: theme.rawValue, icon: theme.icon, isSelected: libraryVM.selectedTheme == theme, color: theme.color) {
                        libraryVM.selectTheme(libraryVM.selectedTheme == theme ? nil : theme)
                    }
                }
            }
            .padding(.horizontal, Layout.horizontalPadding)
        }
    }

    // MARK: - 故事列表
    private var storyList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                let stories = currentStories
                if stories.isEmpty {
                    emptyState
                } else {
                    ForEach(stories) { story in
                        StoryCard(story: story, onTap: {
                            playerVM.play(story: story, playlist: stories)
                        }, onPlay: {
                            playerVM.play(story: story, playlist: stories)
                        })
                        .contextMenu {
                            Button(action: {
                                libraryVM.toggleFavorite(for: story)
                            }) {
                                Label(story.isFavorite ? "取消收藏" : "收藏", systemImage: story.isFavorite ? "heart.slash" : "heart")
                            }
                            if story.isDownloaded {
                                Button(role: .destructive, action: {
                                    libraryVM.deleteDownload(for: story)
                                }) {
                                    Label("删除下载", systemImage: "trash")
                                }
                            } else if story.hasAudio {
                                Button(action: {
                                    Task { await libraryVM.downloadStory(story) }
                                }) {
                                    Label("下载", systemImage: "arrow.down.circle")
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, 16)
            .padding(.bottom, playerVM.isMiniPlayerVisible ? 80 : 20)
        }
    }

    private var currentStories: [Story] {
        switch selectedSegment {
        case 1: return libraryVM.favoriteStories
        case 2: return libraryVM.downloadedStories
        default: return libraryVM.filteredStories
        }
    }

    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            Image(systemName: "books.vertical")
                .font(.system(size: 50))
                .foregroundColor(AppColors.textTertiary)
            Text(emptyMessage)
                .font(AppFonts.body())
                .foregroundColor(AppColors.textSecondary)
            Spacer()
        }
    }

    private var emptyMessage: String {
        switch selectedSegment {
        case 1: return "还没有收藏的故事\n快去发现喜欢的故事吧"
        case 2: return "还没有下载的故事\n下载后可离线收听"
        default: return libraryVM.searchText.isEmpty ? "暂无故事" : "没有找到相关故事"
        }
    }
}

// MARK: - 筛选视图
struct FilterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAge: AgeGroup? = nil
    @State private var selectedStyle: StoryStyle? = nil

    var body: some View {
        NavigationStack {
            List {
                Section("适合年龄") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(AgeGroup.allCases) { age in
                                TagButton(title: age.rawValue, icon: nil, isSelected: selectedAge == age) {
                                    selectedAge = selectedAge == age ? nil : age
                                }
                            }
                        }
                    }
                }

                Section("故事风格") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(StoryStyle.allCases) { style in
                                TagButton(title: style.rawValue, icon: nil, isSelected: selectedStyle == style) {
                                    selectedStyle = selectedStyle == style ? nil : style
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("重置") {
                        selectedAge = nil
                        selectedStyle = nil
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - 预览
struct StoryLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        StoryLibraryView()
            .environmentObject(StoryLibraryViewModel())
            .environmentObject(PlayerViewModel())
    }
}
