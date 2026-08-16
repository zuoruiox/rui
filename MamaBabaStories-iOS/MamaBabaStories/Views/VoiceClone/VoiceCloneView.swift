//
//  VoiceCloneView.swift
//  MamaBabaStories
//
//  声音克隆首页视图
//

import SwiftUI

struct VoiceCloneView: View {
    @EnvironmentObject var voiceVM: VoiceCloneViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @State private var showingCreateSheet = false
    @State private var voiceToDelete: VoiceModel?
    @State private var showingDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // 顶部说明卡片
                    introCard
                        .padding(.horizontal, Layout.horizontalPadding)

                    // 我的声音
                    myVoicesSection
                        .padding(.horizontal, Layout.horizontalPadding)

                    // 录制提示
                    tipsSection
                        .padding(.horizontal, Layout.horizontalPadding)

                    // 录制引导
                    if voiceVM.voiceModels.isEmpty && !voiceVM.isLoading {
                        emptyState
                            .padding(.horizontal, Layout.horizontalPadding)
                    }

                    // 加载中
                    if voiceVM.isLoading {
                        ProgressView("加载中...")
                            .padding(.top, 40)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, playerVM.isMiniPlayerVisible ? 80 : 20)
            }
            .background(AppColors.background)
            .navigationTitle("我的声音")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        voiceVM.selectedOwnerType = .mom
                        voiceVM.newVoiceName = VoiceOwnerType.mom.defaultName
                        showingCreateSheet = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppColors.softOrange)
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateVoiceView(isPresented: $showingCreateSheet)
            }
            .alert("错误", isPresented: $voiceVM.showError) {
                Button("好的", role: .cancel) {}
            } message: {
                Text(voiceVM.errorMessage ?? "未知错误")
            }
            .alert("训练完成！", isPresented: $voiceVM.showingTrainingSuccess) {
                Button("好的", role: .cancel) {}
            } message: {
                Text("你的声音模型已经训练完成，现在可以用你的声音来讲故事啦！")
            }
            .alert("确认删除", isPresented: $showingDeleteConfirm) {
                Button("删除", role: .destructive) {
                    if let model = voiceToDelete {
                        Task { await voiceVM.deleteVoiceModel(model) }
                        voiceToDelete = nil
                    }
                }
                Button("取消", role: .cancel) {
                    voiceToDelete = nil
                }
            } message: {
                Text("删除后将无法恢复，确定要删除「\(voiceToDelete?.name ?? "该声音")」吗？")
            }
            .onChange(of: voiceVM.navigateToRecording) { _, isNavigating in
                if isNavigating {
                    showingCreateSheet = false
                }
            }
            .onAppear {
                Task { await voiceVM.loadData() }
            }
        }
    }

    // MARK: - 介绍卡片
    private var introCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "mic.fill")
                            .foregroundColor(AppColors.softOrange)
                        Text("声音克隆")
                            .font(AppFonts.headline())
                            .foregroundColor(AppColors.textPrimary)
                    }
                    Text("录制几段声音，AI就能模仿你的声音给宝贝讲故事")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "waveform")
                    .font(.system(size: 40))
                    .foregroundColor(AppColors.softOrange.opacity(0.6))
            }

            HStack(spacing: 12) {
                StatBadge(icon: "mic.fill", value: "\(voiceVM.voiceModels.count)", label: "个声音")
                StatBadge(icon: "checkmark.circle.fill", value: "\(voiceVM.voiceModels.filter { $0.statusEnum == .ready }.count)", label: "可用")
                StatBadge(icon: "clock.fill", value: "1分钟", label: "录制时长")
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [AppColors.warmYellow.opacity(0.2), AppColors.softOrange.opacity(0.1)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    // MARK: - 我的声音列表
    private var myVoicesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("我的声音")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
            }

            if !voiceVM.voiceModels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(voiceVM.voiceModels) { model in
                            VoiceModelCard(
                                voiceModel: model,
                                isTraining: model.statusEnum == .training,
                                onTap: {
                                    voiceVM.selectVoiceModel(model)
                                },
                                onPlay: {
                                    voiceVM.tryVoiceModel(model)
                                },
                                onDelete: {
                                    voiceToDelete = model
                                    showingDeleteConfirm = true
                                }
                            )
                        }

                        AddVoiceCard {
                            voiceVM.selectedOwnerType = .mom
                            voiceVM.newVoiceName = VoiceOwnerType.mom.defaultName
                            showingCreateSheet = true
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    // MARK: - 提示区
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(AppColors.warmYellow)
                Text("录制小贴士")
                    .font(AppFonts.headline(size: 18))
                    .foregroundColor(AppColors.textPrimary)
            }

            VStack(spacing: 10) {
                TipRow(icon: "speaker.slash.fill", text: "选择安静的环境，避免背景噪音")
                TipRow(icon: "mic", text: "距离麦克风20-30厘米，保持正常音量")
                TipRow(icon: "text.bubble", text: "清晰自然地朗读提示文字")
                TipRow(icon: "clock", text: "每段录音建议5秒以上")
                TipRow(icon: "list.number", text: "录制1-3段即可，越多效果越好")
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .fill(AppColors.surface)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
    }

    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 20)
            Image(systemName: "mic.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(AppColors.softOrange.opacity(0.5))
            Text("还没有声音模型")
                .font(AppFonts.headline(size: 20))
                .foregroundColor(AppColors.textPrimary)
            Text("点击下方按钮，开始录制你的第一个声音模型")
                .font(AppFonts.body())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            PrimaryButton("开始录制", icon: "mic.fill") {
                voiceVM.selectedOwnerType = .mom
                voiceVM.newVoiceName = VoiceOwnerType.mom.defaultName
                showingCreateSheet = true
            }
            .padding(.top, 8)
            .padding(.horizontal, 40)
            Spacer()
        }
    }
}

// MARK: - 统计徽章
struct StatBadge: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(AppColors.softOrange)
            Text(value)
                .font(AppFonts.caption(size: 14, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
            Text(label)
                .font(AppFonts.caption(size: 11))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppColors.surface.opacity(0.8))
        .cornerRadius(8)
    }
}

// MARK: - 提示行
struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppColors.softOrange)
                .frame(width: 20)
            Text(text)
                .font(AppFonts.caption())
                .foregroundColor(AppColors.textSecondary)
            Spacer()
        }
    }
}

// MARK: - 创建声音视图
struct CreateVoiceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var voiceVM: VoiceCloneViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer().frame(height: 20)

                // 图标
                ZStack {
                    Circle()
                        .fill(AppColors.softOrange.opacity(0.1))
                        .frame(width: 100, height: 100)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.softOrange)
                }

                Text("创建声音模型")
                    .font(AppFonts.title(size: 24))
                    .foregroundColor(AppColors.textPrimary)

                Text("选择是谁的声音，取一个名字")
                    .font(AppFonts.body())
                    .foregroundColor(AppColors.textSecondary)

                VStack(spacing: 20) {
                    // 选择归属
                    VStack(alignment: .leading, spacing: 10) {
                        Text("这是谁的声音？")
                            .font(AppFonts.headline(size: 16))
                            .foregroundColor(AppColors.textPrimary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(VoiceOwnerType.allCases) { type in
                                    Button(action: {
                                        voiceVM.selectedOwnerType = type
                                        if voiceVM.newVoiceName.isEmpty || VoiceOwnerType.allCases.contains(where: { $0.defaultName == voiceVM.newVoiceName }) {
                                            voiceVM.newVoiceName = type.defaultName
                                        }
                                    }) {
                                        VStack(spacing: 6) {
                                            Image(systemName: type.icon)
                                                .font(.system(size: 24, weight: .medium))
                                                .foregroundColor(voiceVM.selectedOwnerType == type ? .white : AppColors.textSecondary)
                                            Text(type.displayName)
                                                .font(AppFonts.caption(size: 12))
                                                .foregroundColor(voiceVM.selectedOwnerType == type ? .white : AppColors.textSecondary)
                                        }
                                        .frame(width: 70, height: 80)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(voiceVM.selectedOwnerType == type ? AppColors.softOrange : AppColors.surfaceVariant)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }

                    // 名称输入
                    VStack(alignment: .leading, spacing: 10) {
                        Text("给这个声音取个名字")
                            .font(AppFonts.headline(size: 16))
                            .foregroundColor(AppColors.textPrimary)

                        TextField("例如：妈妈的声音", text: $voiceVM.newVoiceName)
                            .font(AppFonts.body())
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppColors.surfaceVariant)
                            )
                    }
                }
                .padding(.horizontal, Layout.horizontalPadding)

                Spacer()

                // 创建按钮
                if voiceVM.isCreating {
                    ProgressView("创建中...")
                        .padding(.bottom, 30)
                } else {
                    PrimaryButton("开始录制", icon: "mic.fill", isDisabled: voiceVM.newVoiceName.isEmpty) {
                        Task {
                            let success = await voiceVM.createVoiceModel()
                            if success {
                                isPresented = false
                            }
                            // 如果失败，showError alert 会显示错误信息
                        }
                    }
                    .padding(.horizontal, Layout.horizontalPadding)
                    .padding(.bottom, 30)
                }
            }
            .background(AppColors.background)
            .navigationTitle("新建声音")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                    .disabled(voiceVM.isCreating)
                }
            }
            .alert("错误", isPresented: $voiceVM.showError) {
                Button("好的", role: .cancel) {}
            } message: {
                Text(voiceVM.errorMessage ?? "未知错误")
            }
        }
    }
}

// MARK: - 预览
struct VoiceCloneView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceCloneView()
            .environmentObject(VoiceCloneViewModel())
            .environmentObject(PlayerViewModel())
    }
}