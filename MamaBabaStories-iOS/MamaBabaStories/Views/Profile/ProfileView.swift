//
//  ProfileView.swift
//  MamaBabaStories
//
//  个人中心视图
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var profileVM: ProfileViewModel
    @EnvironmentObject var voiceVM: VoiceCloneViewModel
    @State private var showingLogoutAlert = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // 用户信息卡片
                    userCard
                        .padding(.horizontal, Layout.horizontalPadding)

                    // 孩子档案
                    childrenSection
                        .padding(.horizontal, Layout.horizontalPadding)

                    // 统计数据
                    statsSection
                        .padding(.horizontal, Layout.horizontalPadding)

                    // 会员卡片
                    membershipCard
                        .padding(.horizontal, Layout.horizontalPadding)

                    // 声音管理入口
                    voiceManagementCard
                        .padding(.horizontal, Layout.horizontalPadding)

                    // 设置列表
                    settingsList
                        .padding(.horizontal, Layout.horizontalPadding)

                    // 退出登录
                    logoutButton
                        .padding(.horizontal, Layout.horizontalPadding)
                        .padding(.bottom, 100)
                }
                .padding(.top, 8)
            }
            .background(AppColors.background)
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $profileVM.showingAddChild) {
                AddChildView()
            }
            .alert("确认退出登录？", isPresented: $showingLogoutAlert) {
                Button("取消", role: .cancel) {}
                Button("退出", role: .destructive) {
                    profileVM.logout()
                }
            }
        }
    }

    // MARK: - 用户卡片
    private var userCard: some View {
        HStack(spacing: 16) {
            // 头像
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [AppColors.warmYellow, AppColors.softOrange]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                Text(profileVM.user?.nickname.prefix(1).description ?? "妈")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(profileVM.user?.nickname ?? "未登录")
                    .font(AppFonts.headline(size: 20))
                    .foregroundColor(AppColors.textPrimary)

                Text(profileVM.membershipText)
                    .font(AppFonts.caption())
                    .foregroundColor(profileVM.user?.isMembershipActive == true ? AppColors.warning : AppColors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(profileVM.user?.isMembershipActive == true ? AppColors.warning.opacity(0.15) : AppColors.surfaceVariant)
                    )
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .fill(AppColors.surface)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
    }

    // MARK: - 孩子档案
    private var childrenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("宝贝档案")
                    .font(AppFonts.headline(size: 18))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Button(action: { profileVM.showingAddChild = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AppColors.softOrange)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(profileVM.children) { child in
                        ChildCard(child: child)
                    }
                    AddChildButton {
                        profileVM.showingAddChild = true
                    }
                }
            }
        }
    }

    // MARK: - 统计
    private var statsSection: some View {
        HStack(spacing: 0) {
            StatItem(value: "\(profileVM.totalStoriesPlayed)", label: "已听故事")
            Divider().frame(height: 40)
            StatItem(value: "\(profileVM.totalListeningMinutes)", label: "收听分钟")
            Divider().frame(height: 40)
            StatItem(value: "\(profileVM.favoriteStoriesCount)", label: "收藏故事")
            Divider().frame(height: 40)
            StatItem(value: "\(profileVM.downloadedStoriesCount)", label: "已下载")
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .fill(AppColors.surface)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
    }

    // MARK: - 会员卡片
    private var membershipCard: some View {
        Button(action: { profileVM.showingMembershipPage = true }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [AppColors.warmYellow, AppColors.softOrange]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(profileVM.user?.isMembershipActive == true ? "会员有效期内" : "开通会员")
                        .font(AppFonts.headline(size: 16))
                        .foregroundColor(AppColors.textPrimary)
                    Text(profileVM.user?.isMembershipActive == true ? "享受全部会员权益" : "解锁无限AI创作、多声音模型")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Layout.cornerRadius)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [AppColors.warmYellow.opacity(0.15), AppColors.softOrange.opacity(0.08)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 声音管理
    private var voiceManagementCard: some View {
        Button(action: { profileVM.showingVoiceManagement = true }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppColors.softPink.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.softPink)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("我的声音模型")
                        .font(AppFonts.body(size: 16, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                    Text("已创建\(profileVM.voiceModels.count)个声音模型")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Layout.cornerRadius)
                    .fill(AppColors.surface)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 设置列表
    private var settingsList: some View {
        VStack(spacing: 0) {
            ForEach(profileVM.settingsSections) { section in
                VStack(alignment: .leading, spacing: 0) {
                    Text(section.title)
                        .font(AppFonts.caption(size: 13))
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    VStack(spacing: 0) {
                        ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                            SettingsRow(item: item)
                            if index < section.items.count - 1 {
                                Divider()
                                    .padding(.leading, 56)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: Layout.cornerRadius)
                            .fill(AppColors.surface)
                            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                    )
                }
            }
        }
    }

    // MARK: - 退出登录
    private var logoutButton: some View {
        Button(action: { showingLogoutAlert = true }) {
            Text("退出登录")
                .font(AppFonts.body(size: 16, weight: .medium))
                .foregroundColor(AppColors.error)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: Layout.cornerRadius)
                        .fill(AppColors.surface)
                )
        }
    }
}

// MARK: - 统计项
struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
            Text(label)
                .font(AppFonts.caption(size: 11))
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 孩子卡片
struct ChildCard: View {
    let child: Child

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(AppColors.softBlue.opacity(0.3))
                    .frame(width: 56, height: 56)
                Text(child.avatarEmoji)
                    .font(.system(size: 28))
            }
            Text(child.name)
                .font(AppFonts.caption(size: 12, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
            Text("\(child.age)岁")
                .font(.system(size: 10))
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(width: 70)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.surface)
        )
    }
}

// MARK: - 添加孩子按钮
struct AddChildButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 56, height: 56)
                    Image(systemName: "plus")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.textTertiary)
                }
                Text("添加")
                    .font(AppFonts.caption(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                Text("")
                    .font(.system(size: 10))
            }
            .frame(width: 70)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 设置行
struct SettingsRow: View {
    let item: SettingsItem
    @EnvironmentObject var profileVM: ProfileViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 18))
                .foregroundColor(AppColors.softOrange)
                .frame(width: 28)

            Text(item.title)
                .font(AppFonts.body(size: 15))
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            switch item.type {
            case .toggle(let keyPath):
                Toggle("", isOn: Binding(
                    get: { profileVM[keyPath: keyPath] },
                    set: { _ in
                        profileVM[keyPath: keyPath].toggle()
                        profileVM.savePreferences()
                    }
                ))
                .labelsHidden()
                .tint(AppColors.softOrange)
            case .navigation:
                HStack(spacing: 4) {
                    if let value = item.value {
                        Text(value)
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.textTertiary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textTertiary)
                }
            case .action:
                EmptyView()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - 添加孩子视图
struct AddChildView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var profileVM: ProfileViewModel

    private let emojis = ["🦁", "🐰", "🐻", "🦊", "🐱", "🐶", "🦄", "🐼", "🐨", "🐯", "🦋", "🐙"]

    var body: some View {
        NavigationStack {
            Form {
                Section("宝贝信息") {
                    TextField("宝贝名字", text: $profileVM.newChildName)

                    Picker("性别", selection: $profileVM.newChildGender) {
                        ForEach(Gender.allCases) { gender in
                            Text(gender.rawValue).tag(gender)
                        }
                    }
                    .pickerStyle(.segmented)

                    DatePicker("生日", selection: $profileVM.newChildBirthDate, displayedComponents: .date)
                }

                Section("选择头像") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 12) {
                        ForEach(emojis, id: \.self) { emoji in
                            Button(action: {
                                profileVM.newChildEmoji = emoji
                            }) {
                                Text(emoji)
                                    .font(.system(size: 30))
                                    .frame(width: 50, height: 50)
                                    .background(
                                        Circle()
                                            .fill(profileVM.newChildEmoji == emoji ? AppColors.softOrange.opacity(0.2) : Color.clear)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(profileVM.newChildEmoji == emoji ? AppColors.softOrange : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("添加宝贝")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        profileVM.addChild()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(profileVM.newChildName.isEmpty)
                }
            }
        }
    }
}

// MARK: - 预览
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(ProfileViewModel())
            .environmentObject(VoiceCloneViewModel())
    }
}
