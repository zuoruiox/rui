//
//  HomeViewModel.swift
//  MamaBabaStories
//
//  首页 ViewModel
//

import Foundation
import Combine
import SwiftUI

@MainActor
class HomeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var featuredStories: [Story] = []
    @Published var recentStories: [Story] = []
    @Published var recommendedStories: [Story] = []
    @Published var voiceModels: [VoiceModel] = []
    @Published var currentChild: Child?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var greeting: String = ""
    @Published var greetingIcon: String = "sun.max.fill"
    @Published var quickActions: [QuickAction] = []

    // MARK: - Services
    private let apiClient: APIClientProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
        updateGreeting()
        setupQuickActions()
        // 初始化时加载数据
        Task { await loadData() }
    }

    // MARK: - 加载数据
    func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // 并行加载精选故事和推荐故事
            async let storiesResponse: PaginatedResponse<Story> = apiClient.request(
                .getStories(page: 1, pageSize: 10, theme: nil, isFavorite: nil)
            )

            let result = try await storiesResponse

            // 精选推荐：取前 3 个
            featuredStories = Array(result.list.prefix(3))

            // 最近播放：暂时用全部故事（后端暂无历史记录接口时的降级）
            recentStories = Array(result.list.prefix(5))

            // 推荐：打乱顺序
            recommendedStories = result.list.shuffled()

            // 标记已下载的故事
            for i in 0..<featuredStories.count {
                featuredStories[i].isDownloaded = AudioPlayerManager.shared.isDownloaded(storyId: featuredStories[i].id)
            }
            for i in 0..<recentStories.count {
                recentStories[i].isDownloaded = AudioPlayerManager.shared.isDownloaded(storyId: recentStories[i].id)
            }
            for i in 0..<recommendedStories.count {
                recommendedStories[i].isDownloaded = AudioPlayerManager.shared.isDownloaded(storyId: recommendedStories[i].id)
            }

            // 更新快捷操作的"继续收听"
            if let firstStory = recentStories.first {
                quickActions[0].story = firstStory
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            Logger.error("首页加载失败: \(error)", category: .network)
        }
    }

    // MARK: - 更新问候语
    private func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<8:
            greeting = "早上好呀"
            greetingIcon = "sun.and.horizon.fill"
        case 8..<12:
            greeting = "上午好"
            greetingIcon = "sun.max.fill"
        case 12..<14:
            greeting = "中午好"
            greetingIcon = "fork.knife"
        case 14..<18:
            greeting = "下午好"
            greetingIcon = "sun.max.fill"
        case 18..<22:
            greeting = "晚上好"
            greetingIcon = "moon.stars.fill"
        default:
            greeting = "夜深了"
            greetingIcon = "moon.fill"
        }
    }

    // MARK: - 快捷操作
    private func setupQuickActions() {
        quickActions = [
            QuickAction(id: "continue", title: "继续收听", icon: "play.circle.fill", color: AppColors.softOrange, story: nil),
            QuickAction(id: "bedtime", title: "睡前故事", icon: "moon.stars.fill", color: AppColors.gentleBlue, theme: "bedtime"),
            QuickAction(id: "ai_create", title: "AI创作", icon: "sparkles", color: AppColors.warmYellow, action: .aiCreate),
            QuickAction(id: "voice_clone", title: "声音克隆", icon: "mic.fill", color: AppColors.softPink, action: .voiceClone)
        ]
    }

    // MARK: - 刷新
    func refresh() async {
        updateGreeting()
        await loadData()
    }

    // MARK: - 获取主题故事
    func storiesForTheme(_ theme: String) -> [Story] {
        return recommendedStories.filter { $0.theme == theme }
    }
}

// MARK: - 快捷操作模型
struct QuickAction: Identifiable {
    let id: String
    let title: String
    let icon: String
    let color: Color
    var story: Story? = nil
    var theme: String? = nil
    var action: ActionType = .none

    enum ActionType {
        case none
        case aiCreate
        case voiceClone
        case theme
        case story
    }
}
