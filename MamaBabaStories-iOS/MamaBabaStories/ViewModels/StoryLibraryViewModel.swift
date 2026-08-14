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
    @Published var selectedTheme: String? = nil
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var currentPage = 1
    @Published var hasMore = true
    @Published var showingDownloadProgress = false
    @Published var downloadProgress: [String: Double] = [:]

    // MARK: - 分类
    @Published var categories: [StoryCategory] = []
    @Published var selectedCategory: String? = nil

    // MARK: - 服务
    private let apiClient: APIClientProtocol
    private let pageSize = 20

    // MARK: - Init
    init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
        setupCategories()
        setupSearch()
        // 初始化时加载本地下载状态
        refreshDownloadedStatus()
        // 自动加载第一页
        Task { await loadData() }
        // 监听AI创作保存故事后的刷新通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("StoryLibraryNeedsRefresh"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    // MARK: - 加载数据
    func loadData() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let response: PaginatedResponse<Story> = try await apiClient.request(
                .getStories(page: currentPage, pageSize: pageSize, theme: selectedTheme, isFavorite: nil)
            )

            // 标记已下载的故事
            var stories = response.list
            for i in 0..<stories.count {
                stories[i].isDownloaded = AudioPlayerManager.shared.isDownloaded(storyId: stories[i].id)
            }

            if currentPage == 1 {
                allStories = stories
            } else {
                allStories.append(contentsOf: stories)
            }

            hasMore = response.hasMore
            filteredStories = filterStories(searchText: searchText, theme: selectedTheme)
            favoriteStories = allStories.filter { $0.isFavorite }
            downloadedStories = allStories.filter { $0.isDownloaded }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            Logger.error("加载故事列表失败: \(error)", category: .network)
        }
    }

    // MARK: - 加载更多
    func loadMore() async {
        guard hasMore && !isLoading && !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let nextPage = currentPage + 1
        do {
            let response: PaginatedResponse<Story> = try await apiClient.request(
                .getStories(page: nextPage, pageSize: pageSize, theme: selectedTheme, isFavorite: nil)
            )

            var stories = response.list
            for i in 0..<stories.count {
                stories[i].isDownloaded = AudioPlayerManager.shared.isDownloaded(storyId: stories[i].id)
            }

            allStories.append(contentsOf: stories)
            currentPage = nextPage
            hasMore = response.hasMore
            filteredStories = filterStories(searchText: searchText, theme: selectedTheme)
            favoriteStories = allStories.filter { $0.isFavorite }
            downloadedStories = allStories.filter { $0.isDownloaded }
        } catch {
            Logger.error("加载更多故事失败: \(error)", category: .network)
        }
    }

    // MARK: - 刷新
    func refresh() async {
        isLoadingMore = false
        currentPage = 1
        hasMore = true
        await loadData()
    }

    // MARK: - 分类设置
    private func setupCategories() {
        let themes = ["冒险", "友谊", "家庭", "动物", "魔法", "太空", "自然", "睡前", "勇气", "善良"]
        let icons = ["map.fill", "heart.fill", "house.fill", "pawprint.fill", "sparkles",
                     "moon.stars.fill", "leaf.fill", "moon.fill", "shield.fill", "hand.raised.fill"]

        categories = zip(themes, icons).map { theme, icon in
            StoryCategory(
                id: theme,
                name: theme,
                icon: icon,
                theme: theme,
                stories: nil
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

    private func filterStories(searchText: String, theme: String?) -> [Story] {
        var result = allStories

        if let theme = theme, !theme.isEmpty {
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
    func selectTheme(_ theme: String?) {
        selectedTheme = theme
        currentPage = 1
        hasMore = true
        Task { await loadData() }
    }

    // MARK: - 收藏/取消收藏
    func toggleFavorite(for story: Story) {
        Task {
            do {
                let _: EmptyResponse? = try await apiClient.requestOptional(.toggleFavorite(id: story.id))
                if let index = allStories.firstIndex(where: { $0.id == story.id }) {
                    allStories[index].isFavorite.toggle()
                    filteredStories = filterStories(searchText: searchText, theme: selectedTheme)
                    favoriteStories = allStories.filter { $0.isFavorite }
                }
            } catch {
                errorMessage = "操作失败: \(error.localizedDescription)"
                showError = true
            }
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
                allStories[index].isDownloaded = true
                allStories[index].localAudioPath = player.localFileURL(for: story.id).path
                downloadedStories = allStories.filter { $0.isDownloaded }
            }

            downloadProgress.removeValue(forKey: story.id)
            if downloadProgress.isEmpty {
                showingDownloadProgress = false
            }
            toast("下载完成", type: .success)
        } catch {
            errorMessage = "下载失败: \(error.localizedDescription)"
            showError = true
            downloadProgress.removeValue(forKey: story.id)
            if downloadProgress.isEmpty {
                showingDownloadProgress = false
            }
        }
    }

    // MARK: - 删除下载
    func deleteDownload(for story: Story) {
        try? AudioPlayerManager.shared.deleteDownload(storyId: story.id)
        if let index = allStories.firstIndex(where: { $0.id == story.id }) {
            allStories[index].isDownloaded = false
            allStories[index].localAudioPath = nil
            downloadedStories = allStories.filter { $0.isDownloaded }
        }
    }

    // MARK: - 刷新本地下载状态
    private func refreshDownloadedStatus() {
        for i in 0..<allStories.count {
            allStories[i].isDownloaded = AudioPlayerManager.shared.isDownloaded(storyId: allStories[i].id)
        }
        downloadedStories = allStories.filter { $0.isDownloaded }
    }

    // MARK: - Toast 辅助
    private func toast(_ message: String, type: ToastType = .info) {
        // 简单的通知方式，实际项目可使用专门的 Toast 组件
        NotificationCenter.default.post(name: NSNotification.Name("ToastNotification"), object: nil, userInfo: [
            "message": message,
            "type": type.rawValue
        ])
    }
}

enum ToastType: String {
    case success, error, info, warning
}
