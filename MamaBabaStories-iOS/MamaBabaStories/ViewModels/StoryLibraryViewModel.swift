//
//  StoryLibraryViewModel.swift
//  MamaBabaStories
//
//  故事库 ViewModel
//

import Foundation
import Combine
import SwiftUI

@MainActor
class StoryLibraryViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var allStories: [Story] = []
    @Published var filteredStories: [Story] = []
    @Published var favoriteStories: [Story] = []
    @Published var downloadedStories: [Story] = []
    @Published var playHistory: [PlayHistory] = []
    @Published var selectedTheme: StoryTheme? = nil
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var currentPage = 1
    @Published var hasMore = true
    @Published var showingDownloadProgress = false
    @Published var downloadProgress: [String: Double] = [:]

    // MARK: - 分类
    @Published var categories: [StoryCategory] = []
    @Published var selectedCategory: String? = nil

    // MARK: - Init
    init() {
        setupCategories()
        loadMockData()
        setupSearch()
    }

    // MARK: - 加载数据
    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await Task.sleep(nanoseconds: 500_000_000)
            // 实际项目中调用 API
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - 加载更多
    func loadMore() async {
        guard hasMore && !isLoading else { return }
        currentPage += 1
        await loadData()
    }

    // MARK: - Mock 数据
    private func loadMockData() {
        allStories = Story.mockStories
        filteredStories = Story.mockStories
        favoriteStories = Story.mockFavorites
        downloadedStories = Story.mockStories.filter { $0.isDownloaded }
    }

    // MARK: - 分类设置
    private func setupCategories() {
        categories = StoryTheme.allCases.map { theme in
            StoryCategory(
                id: theme.rawValue,
                name: theme.rawValue,
                icon: theme.icon,
                theme: theme,
                stories: Story.mockStories.filter { $0.theme == theme }
            )
        }
    }

    // MARK: - 搜索
    private func setupSearch() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .combineLatest($selectedTheme)
            .map { [weak self] searchText, theme in
                guard let self = self else { return [] }
                return self.filterStories(searchText: searchText, theme: theme)
            }
            .assign(to: &$filteredStories)
    }

    private func filterStories(searchText: String, theme: StoryTheme?) -> [Story] {
        var result = allStories

        if let theme = theme {
            result = result.filter { $0.theme == theme }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        return result
    }

    // MARK: - 选择主题
    func selectTheme(_ theme: StoryTheme?) {
        selectedTheme = theme
    }

    // MARK: - 收藏/取消收藏
    func toggleFavorite(for story: Story) {
        if let index = allStories.firstIndex(where: { $0.id == story.id }) {
            allStories[index] = Story(
                id: allStories[index].id,
                title: allStories[index].title,
                content: allStories[index].content,
                summary: allStories[index].summary,
                theme: allStories[index].theme,
                style: allStories[index].style,
                targetAgeGroup: allStories[index].targetAgeGroup,
                coverImageURL: allStories[index].coverImageURL,
                coverGradient: allStories[index].coverGradient,
                coverEmoji: allStories[index].coverEmoji,
                audioURL: allStories[index].audioURL,
                localAudioPath: allStories[index].localAudioPath,
                duration: allStories[index].duration,
                wordCount: allStories[index].wordCount,
                voiceModelId: allStories[index].voiceModelId,
                voiceModelName: allStories[index].voiceModelName,
                isAIGenerated: allStories[index].isAIGenerated,
                isFavorite: !allStories[index].isFavorite,
                isDownloaded: allStories[index].isDownloaded,
                playCount: allStories[index].playCount,
                createdAt: allStories[index].createdAt,
                updatedAt: Date(),
                tags: allStories[index].tags,
                characters: allStories[index].characters
            )
            filteredStories = filterStories(searchText: searchText, theme: selectedTheme)
            favoriteStories = allStories.filter { $0.isFavorite }
        }
    }

    // MARK: - 下载故事
    func downloadStory(_ story: Story) async {
        guard !story.isDownloaded else { return }

        downloadProgress[story.id] = 0
        showingDownloadProgress = true

        do {
            let player = AudioPlayerManager.shared
            try await player.downloadStory(story) { [weak self] progress in
                Task { @MainActor in
                    self?.downloadProgress[story.id] = progress
                }
            }

            // 更新故事状态
            if let index = allStories.firstIndex(where: { $0.id == story.id }) {
                allStories[index] = Story(
                    id: allStories[index].id,
                    title: allStories[index].title,
                    content: allStories[index].content,
                    summary: allStories[index].summary,
                    theme: allStories[index].theme,
                    style: allStories[index].style,
                    targetAgeGroup: allStories[index].targetAgeGroup,
                    coverImageURL: allStories[index].coverImageURL,
                    coverGradient: allStories[index].coverGradient,
                    coverEmoji: allStories[index].coverEmoji,
                    audioURL: allStories[index].audioURL,
                    localAudioPath: player.localFileURL(for: story.id).path,
                    duration: allStories[index].duration,
                    wordCount: allStories[index].wordCount,
                    voiceModelId: allStories[index].voiceModelId,
                    voiceModelName: allStories[index].voiceModelName,
                    isAIGenerated: allStories[index].isAIGenerated,
                    isFavorite: allStories[index].isFavorite,
                    isDownloaded: true,
                    playCount: allStories[index].playCount,
                    createdAt: allStories[index].createdAt,
                    updatedAt: Date(),
                    tags: allStories[index].tags,
                    characters: allStories[index].characters
                )
                downloadedStories = allStories.filter { $0.isDownloaded }
            }

            downloadProgress.removeValue(forKey: story.id)
            if downloadProgress.isEmpty {
                showingDownloadProgress = false
            }
        } catch {
            errorMessage = "下载失败: \(error.localizedDescription)"
            showError = true
            downloadProgress.removeValue(forKey: story.id)
        }
    }

    // MARK: - 删除下载
    func deleteDownload(for story: Story) {
        try? AudioPlayerManager.shared.deleteDownload(storyId: story.id)
        if let index = allStories.firstIndex(where: { $0.id == story.id }) {
            allStories[index] = Story(
                id: allStories[index].id,
                title: allStories[index].title,
                content: allStories[index].content,
                summary: allStories[index].summary,
                theme: allStories[index].theme,
                style: allStories[index].style,
                targetAgeGroup: allStories[index].targetAgeGroup,
                coverImageURL: allStories[index].coverImageURL,
                coverGradient: allStories[index].coverGradient,
                coverEmoji: allStories[index].coverEmoji,
                audioURL: allStories[index].audioURL,
                localAudioPath: nil,
                duration: allStories[index].duration,
                wordCount: allStories[index].wordCount,
                voiceModelId: allStories[index].voiceModelId,
                voiceModelName: allStories[index].voiceModelName,
                isAIGenerated: allStories[index].isAIGenerated,
                isFavorite: allStories[index].isFavorite,
                isDownloaded: false,
                playCount: allStories[index].playCount,
                createdAt: allStories[index].createdAt,
                updatedAt: Date(),
                tags: allStories[index].tags,
                characters: allStories[index].characters
            )
            downloadedStories = allStories.filter { $0.isDownloaded }
        }
    }

    // MARK: - 刷新
    func refresh() async {
        currentPage = 1
        hasMore = true
        await loadData()
    }
}
