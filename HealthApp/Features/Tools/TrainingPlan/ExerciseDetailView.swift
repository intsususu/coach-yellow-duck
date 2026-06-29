// ExerciseDetailView.swift
// 小工具 · 训练计划：动作详情。

import SwiftUI
import UIKit

struct ExerciseDetailView: View {
    let exercise: Exercise

    @StateObject private var profileStore = ProfileStore()
    private let isFemaleOverride: Bool?

    init(exercise: Exercise, isFemale: Bool? = nil) {
        self.exercise = exercise
        self.isFemaleOverride = isFemale
    }

    private var isFemale: Bool {
        isFemaleOverride ?? (profileStore.profile.gender == .female)
    }

    private var selectedVideo: String {
        exercise.video(female: isFemale)
    }

    private var accent: Color {
        .exerciseOrange
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                mediaCard
                titleCard
                muscleMapCard
                if !exercise.points.isEmpty {
                    pointsCard
                }
                disclaimer
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .background(Color.appBg.ignoresSafeArea())
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 演示图（Assets 中以英文名命名）。有图则展示动作示意图，否则降级为视频占位。
    private var mediaCard: some View {
        ZStack {
            if let illustration = UIImage(named: exercise.image) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.cardBg)

                Image(uiImage: illustration)
                    .resizable()
                    .scaledToFit()
                    .padding(14)
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.textPrimary)

                VStack(spacing: 10) {
                    Image(systemName: selectedVideo.isEmpty ? "video.slash" : "play.circle.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundColor(.white)

                    Text(selectedVideo.isEmpty ? "演示视频待补充" : "\(isFemale ? "女版" : "男版")演示视频占位")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)

                    if !selectedVideo.isEmpty {
                        Text("素材到位后自动替换为视频播放")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.65))
                    }
                }
                .padding(18)
            }
        }
        .aspectRatio(16.0 / 10.0, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.hairline, lineWidth: exercise.hasImage ? 1 : 0)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(exercise.hasImage ? "\(exercise.name) 动作示意图" : (selectedVideo.isEmpty ? "演示视频待补充" : "演示视频占位")))
    }

    private var titleCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(exercise.nameEn)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.textMuted)
                    }

                    Spacer(minLength: 0)

                    DifficultyBadge(level: exercise.difficulty, color: accent)
                }

                HStack(spacing: 6) {
                    if let primary = exercise.primaryMuscles.first {
                        ExerciseTag(title: "主 · \(primary)",
                                    foreground: accent,
                                    background: accent.opacity(0.10))
                    }
                    ExerciseTag(title: exercise.type)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("肌群")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.textSecondary)
                    Text(exercise.muscleGroups.map(\.displayName).joined(separator: " / "))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var muscleMapCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("肌肉发力图")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    ExerciseTag(title: "高亮主练肌群",
                                foreground: accent,
                                background: accent.opacity(0.10))
                }

                MuscleBodyView(highlighted: Set(exercise.muscleGroups),
                               accent: accent,
                               isFemale: isFemale)
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
            }
        }
    }

    private var pointsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("动作要点")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    if !exercise.setsReps.isEmpty {
                        ExerciseTag(title: exercise.setsReps,
                                    foreground: .exerciseOrange,
                                    background: Color.exerciseOrange.opacity(0.10))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(exercise.points, id: \.self) { point in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(accent)
                                .frame(width: 5, height: 5)
                                .padding(.top, 7)
                            Text(point)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private var disclaimer: some View {
        Text("训练动作仅供参考，请量力而行，必要时在专业指导下进行")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.textMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
    }
}

#Preview {
    NavigationStack {
        ExerciseDetailView(exercise: TrainingPlanData.exercises[0], isFemale: false)
    }
}
