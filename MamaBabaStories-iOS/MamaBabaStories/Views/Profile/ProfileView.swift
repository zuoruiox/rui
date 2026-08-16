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
    @State private var showingPlaybackSpeed = false
    @State private var showingSleepTimer = false
    @State private var selectedPlaybackSpeed: Double = 1.0

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
            .sheet(isPresented: $profileVM.showingMembershipPage) {
                MembershipView()
            }
            .sheet(isPresented: $profileVM.showingVoiceManagement) {
                NavigationStack {
                    VoiceCloneView()
                        .environmentObject(voiceVM)
                }
            }
            .sheet(isPresented: $showingPlaybackSpeed) {
                PlaybackSpeedView(selectedSpeed: $selectedPlaybackSpeed)
            }
            .sheet(isPresented: $showingSleepTimer) {
                SleepTimerView()
            }
            .sheet(isPresented: $profileVM.showingEditProfile, onDismiss: {
                profileVM.saveProfile()
            }) {
                EditProfileView()
                    .environmentObject(profileVM)
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
        Button(action: {
            profileVM.prepareEditProfile()
            profileVM.showingEditProfile = true
        }) {
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
        .buttonStyle(PlainButtonStyle())
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
            ForEach(Array(profileVM.settingsSections.enumerated()), id: \.element.id) { sectionIndex, section in
                VStack(alignment: .leading, spacing: 0) {
                    Text(section.title)
                        .font(AppFonts.caption(size: 13))
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    VStack(spacing: 0) {
                        ForEach(Array(section.items.enumerated()), id: \.element.id) { itemIndex, item in
                            SettingsRow(
                                item: item,
                                onTap: { handleSettingsTap(item) }
                            )
                            if itemIndex < section.items.count - 1 {
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

    private func handleSettingsTap(_ item: SettingsItem) {
        switch item.title {
        case "播放速度":
            showingPlaybackSpeed = true
        case "睡眠定时":
            showingSleepTimer = true
        case "给我们评分":
            if let url = URL(string: "itms-apps://apple.com/app/id000000") {
                UIApplication.shared.open(url)
            }
        case "意见反馈":
            if let url = URL(string: "mailto:feedback@mamababa.com") {
                UIApplication.shared.open(url)
            }
        case "用户协议", "隐私政策", "关于我们":
            // TODO: 跳转到对应页面
            break
        default:
            break
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
                Image(systemName: child.avatarEmoji.isEmpty ? child.genderEnum.icon : child.avatarEmoji)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(AppColors.gentleBlue)
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
    let onTap: () -> Void
    @EnvironmentObject var profileVM: ProfileViewModel
    @State private var isTapped = false

    var body: some View {
        Button(action: { handleTap() }) {
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
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isTapped ? AppColors.surfaceVariant : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isTapped = true }
                .onEnded { _ in isTapped = false }
        )
    }

    private func handleTap() {
        switch item.type {
        case .toggle:
            break // Toggle handles its own tap
        case .navigation, .action:
            onTap()
        }
    }
}

// MARK: - 添加孩子视图
struct AddChildView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var profileVM: ProfileViewModel

    private let avatarIcons = [
        ("hare.fill", AppColors.softOrange),
        ("teddybear.fill", AppColors.warmYellow),
        ("cat.fill", AppColors.softPink),
        ("dog.fill", AppColors.softGreen),
        ("bird.fill", AppColors.gentleBlue),
        ("fish.fill", Color(red: 0.5, green: 0.4, blue: 0.8)),
        ("ladybug.fill", AppColors.error),
        ("leaf.fill", AppColors.softGreen),
        ("star.fill", AppColors.warmYellow),
        ("heart.fill", AppColors.softPink),
        ("moon.fill", AppColors.gentleBlue),
        ("sun.max.fill", AppColors.warmYellow)
    ]

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
                        ForEach(0..<avatarIcons.count, id: \.self) { index in
                            let (iconName, iconColor) = avatarIcons[index]
                            Button(action: {
                                profileVM.newChildEmoji = iconName
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(profileVM.newChildEmoji == iconName ? iconColor.opacity(0.2) : Color.clear)
                                        .frame(width: 50, height: 50)
                                    Image(systemName: iconName)
                                        .font(.system(size: 24))
                                        .foregroundColor(iconColor)
                                }
                                .overlay(
                                    Circle()
                                        .stroke(profileVM.newChildEmoji == iconName ? iconColor : Color.clear, lineWidth: 2)
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

// MARK: - 会员页面
struct MembershipView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundColor(AppColors.warmYellow)

                    Text("会员权益")
                        .font(AppFonts.title(size: 24))
                        .foregroundColor(AppColors.textPrimary)

                    VStack(spacing: 16) {
                        BenefitRow(icon: "sparkles", title: "无限AI创作", desc: "无限制生成专属故事")
                        BenefitRow(icon: "mic.fill", title: "多个声音模型", desc: "创建爸爸、妈妈、奶奶等多个声音")
                        BenefitRow(icon: "arrow.down.circle.fill", title: "离线下载", desc: "下载故事，无网也能听")
                        BenefitRow(icon: "heart.fill", title: "专属故事库", desc: "收藏喜欢的故事，随时回放")
                    }
                    .padding()
                    .background(AppColors.surface)
                    .cornerRadius(Layout.cornerRadius)
                    .padding(.horizontal, Layout.horizontalPadding)

                    PrimaryButton("立即开通会员", icon: "crown.fill") {
                        // TODO: 接入支付
                    }
                    .padding(.horizontal, Layout.horizontalPadding)
                }
            }
            .background(AppColors.background)
            .navigationTitle("会员中心")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let title: String
    let desc: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(AppColors.softOrange)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.body(size: 16, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                Text(desc)
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
        }
    }
}

// MARK: - 播放速度选择
struct PlaybackSpeedView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSpeed: Double

    private let speeds: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        NavigationStack {
            List {
                Section("选择播放速度") {
                    ForEach(speeds, id: \.self) { speed in
                        Button(action: {
                            selectedSpeed = speed
                            dismiss()
                        }) {
                            HStack {
                                Text("\(speed, specifier: "%.2g")x")
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                if abs(selectedSpeed - speed) < 0.01 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppColors.softOrange)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("播放速度")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 睡眠定时
struct SleepTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedOption: Int = 0 // 0=关闭

    private let options = [
        (0, "关闭"),
        (15, "15分钟"),
        (30, "30分钟"),
        (45, "45分钟"),
        (60, "60分钟"),
        (90, "90分钟")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("定时停止播放") {
                    ForEach(options, id: \.0) { minutes, label in
                        Button(action: {
                            selectedOption = minutes
                            dismiss()
                        }) {
                            HStack {
                                Text(label)
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                if selectedOption == minutes {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppColors.softOrange)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("睡眠定时")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 编辑个人资料
struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var profileVM: ProfileViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("头像") {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [AppColors.warmYellow, AppColors.softOrange]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            Text(profileVM.editingNickname.prefix(1).uppercased())
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                Section("个人信息") {
                    HStack {
                        Text("昵称")
                            .foregroundColor(AppColors.textPrimary)
                        TextField("请输入昵称", text: $profileVM.editingNickname)
                            .multilineTextAlignment(.trailing)
                    }

                    if let phone = profileVM.user?.phone, !phone.isEmpty {
                        HStack {
                            Text("手机号")
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text(phone)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    HStack {
                        Text("会员等级")
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        Text(profileVM.user?.membershipTierEnum.displayName ?? "免费版")
                            .foregroundColor(AppColors.warning)
                    }

                    if let expiry = profileVM.user?.membershipExpiryDate, profileVM.user?.isMembershipActive == true {
                        HStack {
                            Text("到期时间")
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text(expiry, style: .date)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }
            .navigationTitle("个人资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        profileVM.saveProfile()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(profileVM.editingNickname.trimmingCharacters(in: .whitespaces).isEmpty)
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
