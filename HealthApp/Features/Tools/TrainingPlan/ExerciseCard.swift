// ExerciseCard.swift
// 小工具 · 训练计划：动作库列表行与共享展示组件。

import SwiftUI
import UIKit

/// 紧凑动作列表行：缩略占位 + 中文名/英文名 + 主练肌群/类型/难度。
/// 同时服务力量动作（Exercise）、拉伸（StretchMove）与 HIIT（HIITMove）。
struct ExerciseRow: View {
    let name: String
    let nameEn: String
    let primaryTag: String?
    let typeTag: String
    let difficulty: Int
    let video: String
    let image: String?
    let accent: Color
    let isFemale: Bool

    init(name: String, nameEn: String, primaryTag: String?, typeTag: String,
         difficulty: Int, video: String, image: String? = nil, accent: Color, isFemale: Bool) {
        self.name = name
        self.nameEn = nameEn
        self.primaryTag = primaryTag
        self.typeTag = typeTag
        self.difficulty = difficulty
        self.video = video
        self.image = image
        self.accent = accent
        self.isFemale = isFemale
    }

    init(exercise: Exercise, accent: Color, isFemale: Bool) {
        self.init(name: exercise.name, nameEn: exercise.nameEn,
                  primaryTag: exercise.primaryMuscles.first, typeTag: exercise.type,
                  difficulty: exercise.difficulty, video: exercise.video(female: isFemale),
                  image: exercise.image, accent: accent, isFemale: isFemale)
    }

    init(stretch: StretchMove, accent: Color, isFemale: Bool) {
        self.init(name: stretch.name, nameEn: stretch.nameEn,
                  primaryTag: stretch.target, typeTag: stretch.kind,
                  difficulty: stretch.difficulty, video: stretch.video,
                  accent: accent, isFemale: isFemale)
    }

    init(hiit: HIITMove, accent: Color, isFemale: Bool) {
        self.init(name: hiit.name, nameEn: hiit.nameEn,
                  primaryTag: nil, typeTag: hiit.kind,
                  difficulty: hiit.difficulty, video: hiit.video,
                  accent: accent, isFemale: isFemale)
    }

    /// 是否有演示图（动作库专用；拉伸 / HIIT 仍走视频占位）。
    private var illustration: UIImage? {
        guard let image, !image.isEmpty else { return nil }
        return UIImage(named: image)
    }

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                Text(nameEn)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.textMuted)
                    .lineLimit(1)
                tags
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textMuted.opacity(0.7))
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: illustration == nil ? 0 : 92, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.hairline, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let illustration {
            // 动作库：展示缩小的动作示意图，撑高卡片
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accent.opacity(0.08))
                .frame(width: 96, height: 70)
                .overlay {
                    Image(uiImage: illustration)
                        .resizable()
                        .scaledToFit()
                        .padding(5)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            // 拉伸 / HIIT：保留视频占位
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accent.opacity(0.10))
                .frame(width: 56, height: 56)
                .overlay {
                    VStack(spacing: 4) {
                        Image(systemName: video.isEmpty ? "video.slash" : "play.fill")
                            .font(.system(size: 17, weight: .semibold))
                        Text(isFemale ? "女版" : "男版")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(accent)
                }
        }
    }

    private var tags: some View {
        HStack(spacing: 5) {
            if let primary = primaryTag, !primary.isEmpty {
                ExerciseTag(title: primary, foreground: accent, background: accent.opacity(0.10))
            }
            ExerciseTag(title: typeTag)
            DifficultyDots(level: difficulty)
        }
        .padding(.top, 4)
    }
}

/// 兼容旧名，避免预览或临时调用点失效。
struct ExerciseCard: View {
    let exercise: Exercise
    let accent: Color

    var body: some View {
        ExerciseRow(exercise: exercise, accent: accent, isFemale: false)
    }
}

/// 难度圆点：实心 ×level + 空心 ×(5-level)，压缩到 1–5。
struct DifficultyDots: View {
    let level: Int

    var body: some View {
        let n = min(max(level, 1), 5)
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(i < n ? Color.exerciseOrange : Color.exerciseOrange.opacity(0.22))
                    .frame(width: 4.5, height: 4.5)
            }
        }
        .accessibilityLabel(Text("难度 \(n)/5"))
    }
}

struct DifficultyBadge: View {
    let level: Int
    var color: Color = .exerciseOrange

    var body: some View {
        Text("难度 \(min(max(level, 1), 5))/5")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
    }
}

struct ExerciseTag: View {
    let title: String
    var foreground: Color = .textSecondary
    var background: Color = .appBg

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(foreground)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(background)
            )
    }
}

// MARK: - 图片占位（保留供 TP03 详情页复用）

struct TrainingIllustrationView: View {
    let imageName: String
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color
    let aspectRatio: CGFloat

    var body: some View {
        ZStack {
            if let image = UIImage(named: imageName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(8)
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(aspectRatio, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(accent.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(title)：\(subtitle)"))
    }

    private var placeholder: some View {
        VStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(accent)
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.textMuted)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.72)
        }
        .padding(8)
    }
}

#Preview {
    ExerciseRow(exercise: TrainingPlanData.exercises[0], accent: .brandBlue, isFemale: false)
        .padding()
        .background(Color.appBg)
}
