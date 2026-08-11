//
//  CustomButton.swift
//  MamaBabaStories
//
//  自定义按钮组件
//

import SwiftUI

// MARK: - 主按钮
struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isDisabled: Bool = false
    var isLoading: Bool = false
    var color: Color = AppColors.softOrange
    var height: CGFloat = Layout.buttonHeight

    init(_ title: String, icon: String? = nil, color: Color = AppColors.softOrange, isDisabled: Bool = false, isLoading: Bool = false, height: CGFloat = Layout.buttonHeight, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.isDisabled = isDisabled
        self.isLoading = isLoading
        self.height = height
        self.action = action
    }

    var body: some View {
        Button(action: {
            if !isDisabled && !isLoading {
                action()
            }
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(title)
                    .font(AppFonts.button())
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: Layout.cornerRadius)
                    .fill(isDisabled ? Color.gray.opacity(0.3) : color)
                    .shadow(color: color.opacity(isDisabled ? 0 : 0.3), radius: 8, x: 0, y: 4)
            )
        }
        .disabled(isDisabled || isLoading)
    }
}

// MARK: - 次要按钮
struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var color: Color = AppColors.softOrange
    var height: CGFloat = Layout.buttonHeight

    init(_ title: String, icon: String? = nil, color: Color = AppColors.softOrange, height: CGFloat = Layout.buttonHeight, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.height = height
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(AppFonts.button(size: 15))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: Layout.cornerRadius)
                    .fill(color.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cornerRadius)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - 图标圆形按钮
struct CircleIconButton: View {
    let icon: String
    let action: () -> Void
    var size: CGFloat = 48
    var color: Color = AppColors.softOrange
    var iconColor: Color = .white
    var iconSize: CGFloat = 20

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(color)
                        .shadow(color: color.opacity(0.3), radius: 6, x: 0, y: 3)
                )
        }
    }
}

// MARK: - 标签按钮
struct TagButton: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void
    var color: Color = AppColors.softOrange

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                Text(title)
                    .font(AppFonts.caption(size: 13))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color : Color.gray.opacity(0.1))
            )
            .foregroundColor(isSelected ? .white : AppColors.textSecondary)
        }
    }
}

// MARK: - 预览
struct CustomButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            PrimaryButton("开始讲故事", icon: "play.fill") {}
            PrimaryButton("加载中", isLoading: true) {}
            SecondaryButton("选择声音", icon: "mic.fill") {}
            HStack(spacing: 16) {
                CircleIconButton(icon: "play.fill") {}
                CircleIconButton(icon: "heart.fill", action: {}, color: AppColors.softPink)
                CircleIconButton(icon: "bookmark.fill", action: {}, color: AppColors.gentleBlue)
            }
            HStack {
                TagButton(title: "冒险", icon: "map.fill", isSelected: true) {}
                TagButton(title: "温馨", icon: "heart.fill", isSelected: false) {}
                TagButton(title: "睡前", icon: "moon.fill", isSelected: false) {}
            }
        }
        .padding()
        .background(AppColors.background)
    }
}
