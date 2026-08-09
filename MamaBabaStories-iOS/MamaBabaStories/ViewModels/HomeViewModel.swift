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
    @Published var quickActions: [QuickAction] = []

    // MARK: - Services
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init() {
        updateGreeting()
        setupQuickActions()
        loadMockData()
    }

    // MARK: - 加载数据
    func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            // 模拟网络请求
            try await Task.sleep(nanoseconds: 500_000_000)

            // 实际项目中使用 API
            // featuredStories = try await apiClient.request(.getFeaturedStories)
            // recentStories = try await apiClient.request(.getRecentStories(limit: 5))
            // voiceModels = try await voiceService.getVoiceModels()

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
        }
    }

    // MARK: - 加载 Mock 数据（预览和开发用）
    private func loadMockData() {
        featuredStories = Array(Story.mockStories.prefix(3))
        recentStories = Array(Story.mockStories.suffix(4))
        recommendedStories = Story.mockStories.shuffled()
        voiceModels = [VoiceModel.mockMom, VoiceModel.mockDad]
        currentChild = Child.mock
    }

    // MARK: - 更新问候语
    private func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<8:
            greeting = "早上好呀 ☀️"
        case 8..<12:
            greeting = "上午好 🌤️"
        case 12..<14:
            greeting = "中午好 🍱"
        case 14..<18:
            greeting = "下午好 🌻"
        case 18..<22:
            greeting = "晚上好 🌙"
        default:
            greeting = "夜深了 🌟"
        }
    }

    // MARK: - 快捷操作
    private func setupQuickActions() {
        quickActions = [
            QuickAction(id: "continue", title: "继续收听", icon: "play.circle.fill", color: AppColors.softOrange, story: Story.mockStories.first),
            QuickAction(id: "bedtime", title: "睡前故事", icon: "moon.stars.fill", color: AppColors.gentleBlue, theme: .bedtime),
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
    func storiesForTheme(_ theme: StoryTheme) -> [Story] {
        return Story.mockStories.filter { $0.theme == theme }
    }
}

// MARK: - 快捷操作模型
struct QuickAction: Identifiable {
    let id: String
    let title: String
    let icon: String
    let color: Color
    var story: Story? = nil
    var theme: StoryTheme? = nil
    var action: ActionType = .none

    enum ActionType {
        case none
        case aiCreate
        case voiceClone
        case theme
        case story
    }
}
