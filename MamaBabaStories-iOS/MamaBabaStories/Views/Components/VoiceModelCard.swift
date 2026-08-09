//
//  VoiceModelCard.swift
//  MamaBabaStories
//
//  声音模型卡片组件
//

import SwiftUI

struct VoiceModelCard: View {
    let voiceModel: VoiceModel
    var isSelected: Bool = false
    var isTraining: Bool = false
    var onTap: (() -> Void)? = nil
    var onPlay: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(spacing: 12) {
                // 头像区域
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: voiceModel.coverColor ?? "#FFB74D") ?? AppColors.warmYellow,
                                    (Color(hex: voiceModel.coverColor ?? "#FFB74D") ?? AppColors.warmYellow).opacity(0.6)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)

                    Text(voiceModel.ownerType.emoji)
                        .font(.system(size: 32))

                    // 状态指示器
                    if voiceModel.status == .ready {
                        Circle()
                            .fill(AppColors.success)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 22, y: 22)
                    } else if voiceModel.status == .training {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.warning))
                            .frame(width: 18, height: 18)
                            .offset(x: 22, y: 22)
                    }
                }

                // 名称
                VStack(spacing: 2) {
                    Text(voiceModel.name)
                        .font(AppFonts.caption(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    Text(voiceModel.statusDescription)
                        .font(.system(size: 10))
                        .foregroundColor(statusColor)
                }

                // 训练进度
                if voiceModel.status == .training {
                    ProgressView(value: voiceModel.trainingProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: AppColors.warning))
                        .frame(width: 60)
                }

                // 操作按钮
                if voiceModel.status == .ready {
                    HStack(spacing: 8) {
                        Button(action: { onPlay?() }) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(AppColors.softOrange)
                                .clipShape(Circle())
                        }

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(AppColors.success)
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .frame(width: 100)
            .background(
                RoundedRectangle(cornerRadius: Layout.cornerRadius)
                    .fill(isSelected ? AppColors.softOrange.opacity(0.1) : AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Layout.cornerRadius)
                            .stroke(isSelected ? AppColors.softOrange : Color.clear, lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            if voiceModel.status == .ready {
                Button(action: { onPlay?() }) {
                    Label("试听", systemImage: "play.circle")
                }
            }
            Button(role: .destructive, action: { onDelete?() }) {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private var statusColor: Color {
        switch voiceModel.status {
        case .ready: return AppColors.success
        case .training, .uploading: return AppColors.warning
        case .failed: return AppColors.error
        case .recording: return AppColors.info
        }
    }
}

// MARK: - 添加声音卡片
struct AddVoiceCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 64, height: 64)

                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(AppColors.textTertiary)
                }

                Text("添加声音")
                    .font(AppFonts.caption(size: 13))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .frame(width: 100)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 预览
struct VoiceModelCard_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 12) {
            VoiceModelCard(voiceModel: .mockMom, isSelected: true)
            VoiceModelCard(voiceModel: .mockDad)
            VoiceModelCard(voiceModel: .mockTraining)
            AddVoiceCard {}
        }
        .padding()
        .background(AppColors.background)
        .previewLayout(.sizeThatFits)
    }
}
