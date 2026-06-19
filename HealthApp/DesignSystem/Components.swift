// Components.swift
// 基础可复用 UI 组件。PRD §4.3 卡片/圆环/Pill 样式。

import SwiftUI

/// 白底圆角卡片：圆角 16、轻描边 + 轻阴影。可指定背景色（如体重 hero 卡）。
struct CardView<Content: View>: View {
    var background: Color = .cardBg
    var padding: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.hairline, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

/// 环形进度指标：环 + 大号数值 + 单位 + 标签。睡眠/运动/卡路里复用。
struct RingMetric: View {
    let value: String          // 主数值，如 "7.3"
    var unit: String = ""      // 单位，如 "h" / "m" / "千卡"
    let label: String          // 底部标签，如 "睡眠"
    let progress: Double       // 0–1
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: max(0, min(1, progress)))
                    .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(value)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(.textPrimary)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: 50)
            }
            .frame(width: 64, height: 64)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 胶囊按钮。primary = 实心主色；否则浅底描边。
struct PillButton: View {
    let title: String
    var systemImage: String? = nil
    var filled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundColor(filled ? .white : .brandBlue)
            .background(filled ? Color.brandBlue : Color.brandBlue.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// 分区标题 + 可选右侧动作。
struct SectionTitle<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.textPrimary)
            Spacer()
            trailing
        }
    }
}

extension SectionTitle where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title: title) { EmptyView() }
    }
}
