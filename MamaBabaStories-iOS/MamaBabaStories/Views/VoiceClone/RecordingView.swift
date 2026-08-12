//
//  RecordingView.swift
//  MamaBabaStories
//
//  录音界面视图
//

import SwiftUI

struct RecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var voiceVM: VoiceCloneViewModel
    @State private var showingPermissionAlert = false
    @State private var animatePulse = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 顶部进度
                    progressHeader
                        .padding(.top, 20)

                    Spacer()

                    // 提示文本
                    promptSection
                        .padding(.horizontal, Layout.horizontalPadding)

                    Spacer()

                    // 波形显示
                    waveformSection
                        .padding(.horizontal, Layout.horizontalPadding)

                    Spacer()

                    // 录音质量指示
                    if voiceVM.isRecording {
                        qualityIndicator
                            .padding(.horizontal, Layout.horizontalPadding)
                    }

                    Spacer()

                    // 录音按钮
                    recordButtonSection
                        .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        if voiceVM.isRecording {
                            voiceVM.cancelRecording()
                        }
                        voiceVM.resetRecordingFlow()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(voiceVM.progressText)
                        .font(AppFonts.headline(size: 17))
                        .foregroundColor(AppColors.textPrimary)
                }
            }
            .alert("需要麦克风权限", isPresented: $showingPermissionAlert) {
                Button("去设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("请在设置中允许访问麦克风，才能录制声音")
            }
            .overlay {
                if voiceVM.isUploading {
                    uploadProgressOverlay
                }
                if voiceVM.isTraining {
                    trainingOverlay
                }
            }
        }
    }

    // MARK: - 进度头部
    private var progressHeader: some View {
        VStack(spacing: 8) {
            ProgressView(value: min(Double(voiceVM.recordings.count + (voiceVM.isRecording ? 1 : 0)) / Double(VoiceCloneConfig.minRecordings), 1.0))
                .progressViewStyle(LinearProgressViewStyle(tint: AppColors.softOrange))
                .padding(.horizontal, Layout.horizontalPadding)

            HStack {
                Text("已录制 \(voiceVM.recordings.count) 段")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("至少需要 \(VoiceCloneConfig.minRecordings) 段")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.horizontal, Layout.horizontalPadding)
        }
    }

    // MARK: - 提示文本区
    private var promptSection: some View {
        VStack(spacing: 16) {
            Text("📖 请朗读以下文字")
                .font(AppFonts.caption())
                .foregroundColor(AppColors.textTertiary)

            Text(voiceVM.currentPrompt.text)
                .font(AppFonts.body(size: 20))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(8)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: Layout.cornerRadius)
                        .fill(AppColors.surface)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                )

            if voiceVM.isVoiceDetected && voiceVM.isRecording {
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .foregroundColor(AppColors.success)
                    Text("正在录音...")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.success)
                }
            }
        }
    }

    // MARK: - 波形区
    private var waveformSection: some View {
        VStack(spacing: 16) {
            // 时长显示
            Text(formatDuration(voiceVM.recordingDuration))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(voiceVM.isRecordingLongEnough ? AppColors.success : AppColors.textPrimary)
                .monospacedDigit()

            Text(voiceVM.isRecordingLongEnough ? "时长已达标，可以停止" : "至少需要\(Int(AudioConfig.minRecordingDuration))秒")
                .font(AppFonts.caption())
                .foregroundColor(voiceVM.isRecordingLongEnough ? AppColors.success : AppColors.textTertiary)

            // 波形
            HStack(spacing: 3) {
                ForEach(0..<50, id: \.self) { index in
                    let level = voiceVM.waveformData[safe: index] ?? 0
                    let barHeight = max(4, CGFloat(level) * 60)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [AppColors.softOrange, AppColors.warmYellow]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 4, height: voiceVM.isRecording ? barHeight : 4)
                        .animation(.easeOut(duration: 0.1), value: level)
                }
            }
            .frame(height: 60)
        }
    }

    // MARK: - 质量指示
    private var qualityIndicator: some View {
        HStack(spacing: 16) {
            QualityItem(
                icon: voiceVM.recordingQuality?.hasClipping == true ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                text: "音量",
                isGood: voiceVM.recordingQuality?.hasClipping != true && voiceVM.recordingQuality?.isTooQuiet != true,
                color: (voiceVM.recordingQuality?.hasClipping == true || voiceVM.recordingQuality?.isTooQuiet == true) ? AppColors.warning : AppColors.success
            )
            QualityItem(
                icon: "waveform",
                text: "环境",
                isGood: (voiceVM.recordingQuality?.snr ?? 30) >= Double(AudioConfig.minSNR),
                color: (voiceVM.recordingQuality?.snr ?? 30) >= Double(AudioConfig.minSNR) ? AppColors.success : AppColors.warning
            )
            QualityItem(
                icon: "clock.fill",
                text: "时长",
                isGood: voiceVM.isRecordingLongEnough,
                color: voiceVM.isRecordingLongEnough ? AppColors.success : AppColors.textTertiary
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.surface)
        )
    }

    // MARK: - 录音按钮区
    private var recordButtonSection: some View {
        HStack(spacing: 40) {
            if voiceVM.isRecording {
                // 删除按钮
                Button(action: {
                    voiceVM.cancelRecording()
                }) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(AppColors.error.opacity(0.15))
                                .frame(width: 56, height: 56)
                            Image(systemName: "xmark")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(AppColors.error)
                        }
                        Text("重录")
                            .font(AppFonts.caption(size: 11))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                // 停止按钮
                Button(action: {
                    voiceVM.stopRecording()
                }) {
                    ZStack {
                        Circle()
                            .fill(AppColors.softOrange)
                            .frame(width: 80, height: 80)
                            .shadow(color: AppColors.softOrange.opacity(0.4), radius: 15)
                            .scaleEffect(animatePulse ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: animatePulse)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white)
                            .frame(width: 24, height: 24)
                    }
                }
                .onAppear { animatePulse = true }

                // 暂停/恢复按钮
                Button(action: {
                    if voiceVM.isPaused {
                        voiceVM.resumeRecording()
                    } else {
                        voiceVM.pauseRecording()
                    }
                }) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(AppColors.gentleBlue.opacity(0.15))
                                .frame(width: 56, height: 56)
                            Image(systemName: voiceVM.isPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(AppColors.gentleBlue)
                        }
                        Text(voiceVM.isPaused ? "继续" : "暂停")
                            .font(AppFonts.caption(size: 11))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            } else {
                // 开始录音按钮
                Button(action: {
                    voiceVM.startRecording()
                }) {
                    ZStack {
                        Circle()
                            .fill(AppColors.softOrange)
                            .frame(width: 80, height: 80)
                            .shadow(color: AppColors.softOrange.opacity(0.4), radius: 15)

                        Image(systemName: "mic.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }

                // 完成训练按钮（如果已录制足够）
                if voiceVM.canStartTraining {
                    Button(action: {
                        voiceVM.startTraining()
                    }) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.success.opacity(0.15))
                                    .frame(width: 56, height: 56)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(AppColors.success)
                            }
                            Text("完成")
                                .font(AppFonts.caption(size: 11))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 上传进度遮罩
    private var uploadProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.softOrange))
                    .scaleEffect(1.5)
                Text("正在上传... \(Int(voiceVM.uploadProgress * 100))%")
                    .font(AppFonts.body())
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
    }

    // MARK: - 训练遮罩
    private var trainingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView(value: voiceVM.trainingProgress)
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.softOrange))
                    .scaleEffect(2)
                    .frame(width: 80, height: 80)

                VStack(spacing: 8) {
                    Text("AI正在学习你的声音")
                        .font(AppFonts.headline(size: 18))
                        .foregroundColor(.white)
                    Text("请稍候，这需要1-3分钟")
                        .font(AppFonts.caption())
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - 质量项
struct QualityItem: View {
    let icon: String
    let text: String
    let isGood: Bool
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(text)
                .font(AppFonts.caption(size: 12))
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

// MARK: - Array 安全访问
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - 预览
struct RecordingView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingView()
            .environmentObject(VoiceCloneViewModel())
    }
}
