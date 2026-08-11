//
//  StoryCard.swift
//  MamaBabaStories
//
//  故事卡片组件
//

import SwiftUI

// MARK: - 故事卡片（横向）
struct StoryCard: View {
    let story: Story
    var isPlaying: Bool = false
    var onTap: (() -> Void)? = nil
    var onPlay: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 14) {
                // 封面
                StoryCoverView(story: story, size: CGSize(width: 80, height: 80))

                // 信息
                VStack(alignment: .leading, spacing: 6) {
                    Text(story.title)
                        .font(AppFonts.headline(size: 16))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if let voiceName = story.voiceModelName {
                            Label(voiceName, systemImage: "mic.fill")
                                .font(AppFonts.caption(size: 11))
                                .foregroundColor(AppColors.textTertiary)
                        }

                        Label(story.formattedDuration, systemImage: "clock.fill")
                            .font(AppFonts.caption(size: 11))
                            .foregroundColor(AppColors.textTertiary)
                    }

                    HStack(spacing: 4) {
                        Text(story.themeDisplayName)
                            .font(AppFonts.caption(size: 10))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(themeColor(story.theme).opacity(0.2))
                            .foregroundColor(themeColor(story.theme).opacity(0.8))
                            .cornerRadius(6)

                        if story.isAIGenerated {
                            Text("AI")
                                .font(AppFonts.caption(size: 10))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(AppColors.warmYellow.opacity(0.3))
                                .foregroundColor(.orange)
                                .cornerRadius(6)
                        }

                        if story.isDownloaded {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.success)
                        }
                    }
                }

                Spacer()

                // 播放按钮
                Button(action: { onPlay?() }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(AppColors.softOrange)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: Layout.cornerRadius)
                    .fill(AppColors.surface)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 故事封面
struct StoryCoverView: View {
    let story: Story
    var size: CGSize = CGSize(width: 120, height: 120)

    var body: some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                gradient: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Emoji
            Text(story.coverEmoji)
                .font(.system(size: size.width * 0.4))

            // 播放指示器
            if story.hasAudio {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "headphones")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(4)
                            .background(Color.black.opacity(0.2))
                            .clipShape(Circle())
                            .padding(6)
                    }
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .cornerRadius(Layout.smallCornerRadius)
    }

    private var gradientColors: Gradient {
        if let hexColors = story.coverGradient, hexColors.count >= 2 {
            return Gradient(colors: hexColors.map { Color(hex: $0) })
        }
        return Gradient(colors: [themeColor(story.theme), themeColor(story.theme).opacity(0.6)])
    }
}

// MARK: - 主题颜色辅助函数
private func themeColor(_ theme: String) -> Color {
    switch theme {
    case "adventure", "courage", "冒险", "勇气": return AppColors.softOrange
    case "friendship", "友谊": return AppColors.softPink
    case "family", "kindness", "家庭", "善良": return AppColors.warmYellow
    case "animals", "nature", "动物", "自然": return AppColors.softGreen
    case "magic", "魔法": return AppColors.gentleBlue
    case "space", "太空": return Color(red: 0.5, green: 0.4, blue: 0.8)
    case "bedtime", "睡前": return AppColors.gentleBlue
    default: return AppColors.softOrange
    }
}

// MARK: - 大故事卡片（首页推荐）
struct FeaturedStoryCard: View {
    let story: Story
    var onTap: (() -> Void)? = nil
    var onPlay: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 0) {
                // 封面
                ZStack(alignment: .bottomLeading) {
                    StoryCoverView(story: story, size: CGSize(width: 280, height: 180))
                        .cornerRadius(Layout.cornerRadius, corners: [.topLeft, .topRight])

                    // 渐变遮罩
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .black.opacity(0.5)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 60)
                    .cornerRadius(Layout.cornerRadius, corners: [.topLeft, .topRight])

                    // 时长标签
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                        Text(story.formattedDuration)
                            .font(AppFonts.caption(size: 11))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(8)
                    .padding(10)
                }

                // 信息区
                VStack(alignment: .leading, spacing: 6) {
                    Text(story.title)
                        .font(AppFonts.headline(size: 17))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    if let summary = story.summary {
                        Text(summary)
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    }

                    HStack {
                        if let voiceName = story.voiceModelName {
                            Label(voiceName, systemImage: "mic.fill")
                                .font(AppFonts.caption(size: 11))
                                .foregroundColor(AppColors.textTertiary)
                        }
                        Spacer()
                        Button(action: { onPlay?() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10))
                                Text("播放")
                                    .font(AppFonts.caption(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(AppColors.softOrange)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(14)
            }
            .frame(width: 280)
            .background(
                RoundedRectangle(cornerRadius: Layout.cornerRadius)
                    .fill(AppColors.surface)
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 圆角扩展
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - 预览
struct StoryCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    FeaturedStoryCard(story: Story.mockStories[0])
                    FeaturedStoryCard(story: Story.mockStories[1])
                }
                .padding(.horizontal)
            }

            VStack(spacing: 12) {
                StoryCard(story: Story.mockStories[0])
                StoryCard(story: Story.mockStories[1], isPlaying: true)
            }
            .padding(.horizontal)
        }
        .background(AppColors.background)
        .previewLayout(.sizeThatFits)
    }
}
