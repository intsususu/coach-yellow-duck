// TrainingPlanPresets.swift
// 小工具 · 训练计划：力量训练「训练计划」预设（顶部第一个卡片）+ 计划详情页。
// 每个预设引用 TrainingPlanData 内置动作（按英文名），并附建议组次。

import SwiftUI

// MARK: - 预设训练计划

struct TrainingPlanItem: Identifiable {
    let id = UUID()
    let nameEn: String
    let setsReps: String

    var exercise: Exercise? { TrainingPlanData.exercise(nameEn) }
}

struct TrainingPlanPreset: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String          // 一句话目标
    let category: MuscleCategory
    let level: String             // 入门 / 进阶
    let durationMin: Int          // 预计时长
    let items: [TrainingPlanItem]

    var exercises: [Exercise] { items.compactMap { $0.exercise } }
}

enum TrainingPlanPresets {
    static let all: [TrainingPlanPreset] = [
        // MARK: 胸
        TrainingPlanPreset(title: "胸部增肌基础", subtitle: "推举打底，刺激胸大肌中缝", category: .chest, level: "入门", durationMin: 40, items: [
            .init(nameEn: "Dumbbell Bench Press", setsReps: "4 组 × 10 次"),
            .init(nameEn: "Dumbbell Incline Bench Press", setsReps: "3 组 × 12 次"),
            .init(nameEn: "Cable Crossover", setsReps: "3 组 × 15 次"),
            .init(nameEn: "Push Ups", setsReps: "3 组 × 力竭"),
        ]),
        TrainingPlanPreset(title: "徒手胸部塑形", subtitle: "无器械，在家也能练", category: .chest, level: "入门", durationMin: 25, items: [
            .init(nameEn: "Push Ups", setsReps: "4 组 × 12 次"),
            .init(nameEn: "Wide Hand Push Up", setsReps: "3 组 × 12 次"),
            .init(nameEn: "Diamond Push Up", setsReps: "3 组 × 力竭"),
            .init(nameEn: "Chest Dip", setsReps: "3 组 × 力竭"),
        ]),
        TrainingPlanPreset(title: "胸部进阶强化", subtitle: "大重量推举 + 孤立夹胸", category: .chest, level: "进阶", durationMin: 45, items: [
            .init(nameEn: "Barbell Bench Press", setsReps: "5 组 × 6 次"),
            .init(nameEn: "Dumbbell Incline Bench Press", setsReps: "4 组 × 10 次"),
            .init(nameEn: "Dumbbell Fly", setsReps: "3 组 × 12 次"),
            .init(nameEn: "Chest Dip", setsReps: "3 组 × 力竭"),
        ]),
        // MARK: 肩
        TrainingPlanPreset(title: "圆肩三角肌", subtitle: "前中后束兼顾，撑起肩线", category: .shoulders, level: "进阶", durationMin: 35, items: [
            .init(nameEn: "Dumbbell Seated Shoulder Press", setsReps: "4 组 × 10 次"),
            .init(nameEn: "Dumbbell Lateral Raise", setsReps: "4 组 × 15 次"),
            .init(nameEn: "Prone Y Raise", setsReps: "3 组 × 15 次"),
            .init(nameEn: "Cable Front Raise", setsReps: "3 组 × 12 次"),
        ]),
        TrainingPlanPreset(title: "肩部稳定与后束", subtitle: "改善圆肩，强化后链", category: .shoulders, level: "入门", durationMin: 30, items: [
            .init(nameEn: "Resistance Band External Rotation", setsReps: "3 组 × 15 次"),
            .init(nameEn: "Prone Y Raise", setsReps: "3 组 × 15 次"),
            .init(nameEn: "Barbell Rear Delt Row", setsReps: "3 组 × 12 次"),
            .init(nameEn: "Cable Lateral Raise", setsReps: "3 组 × 15 次"),
        ]),
        TrainingPlanPreset(title: "肩部围度塑形", subtitle: "推举打底 + 三向平举", category: .shoulders, level: "入门", durationMin: 30, items: [
            .init(nameEn: "Dumbbell Seated Shoulder Press", setsReps: "4 组 × 10 次"),
            .init(nameEn: "Dumbbell Lateral Raise", setsReps: "4 组 × 15 次"),
            .init(nameEn: "Cable Front Raise", setsReps: "3 组 × 12 次"),
            .init(nameEn: "Barbell Shrug", setsReps: "3 组 × 15 次"),
        ]),
        // MARK: 背
        TrainingPlanPreset(title: "背部宽厚基础", subtitle: "纵向下拉 + 横向划船", category: .back, level: "进阶", durationMin: 45, items: [
            .init(nameEn: "Pull Up", setsReps: "4 组 × 力竭"),
            .init(nameEn: "Cable Wide Grip Lat Pulldown", setsReps: "4 组 × 12 次"),
            .init(nameEn: "Cable Seated Row", setsReps: "3 组 × 12 次"),
            .init(nameEn: "Dumbbell Bent Over Row", setsReps: "3 组 × 12 次"),
        ]),
        TrainingPlanPreset(title: "新手友好背部", subtitle: "有辅助也能练出背阔肌", category: .back, level: "入门", durationMin: 35, items: [
            .init(nameEn: "Assisted Pull Up", setsReps: "4 组 × 10 次"),
            .init(nameEn: "Cable Pulldown", setsReps: "3 组 × 12 次"),
            .init(nameEn: "Lever Seated Row", setsReps: "3 组 × 12 次"),
            .init(nameEn: "Hyperextension", setsReps: "3 组 × 15 次"),
        ]),
        TrainingPlanPreset(title: "背部线条划船", subtitle: "多角度划船刻画背沟", category: .back, level: "入门", durationMin: 35, items: [
            .init(nameEn: "Cable Seated Row", setsReps: "4 组 × 12 次"),
            .init(nameEn: "Dumbbell Bent Over Row", setsReps: "3 组 × 12 次"),
            .init(nameEn: "Lever Seated Row", setsReps: "3 组 × 12 次"),
            .init(nameEn: "Hyperextension", setsReps: "3 组 × 15 次"),
        ]),
        // MARK: 腿
        TrainingPlanPreset(title: "下肢力量基础", subtitle: "深蹲硬拉打地基", category: .lower, level: "进阶", durationMin: 50, items: [
            .init(nameEn: "Barbell Back Squat", setsReps: "4 组 × 8 次"),
            .init(nameEn: "Dumbbell Romanian Deadlift", setsReps: "3 组 × 10 次"),
            .init(nameEn: "Dumbbell Lunge", setsReps: "3 组 × 12 次/侧"),
            .init(nameEn: "Leg Extension", setsReps: "4 组 × 15 次"),
        ]),
        TrainingPlanPreset(title: "翘臀计划", subtitle: "臀推主导，练出臀线", category: .lower, level: "入门", durationMin: 35, items: [
            .init(nameEn: "Hip Thrusts", setsReps: "4 组 × 12 次"),
            .init(nameEn: "Dumbbell Goblet Squat", setsReps: "3 组 × 15 次"),
            .init(nameEn: "Butt Bridge", setsReps: "3 组 × 15 次"),
            .init(nameEn: "Forward Lunge", setsReps: "3 组 × 12 次/侧"),
        ]),
        TrainingPlanPreset(title: "居家腿臀", subtitle: "无器械，徒手练腿臀", category: .lower, level: "入门", durationMin: 25, items: [
            .init(nameEn: "Air Squat", setsReps: "4 组 × 20 次"),
            .init(nameEn: "Forward Lunge", setsReps: "3 组 × 12 次/侧"),
            .init(nameEn: "Butt Bridge", setsReps: "3 组 × 20 次"),
            .init(nameEn: "Hip Thrusts", setsReps: "3 组 × 15 次"),
        ]),
        // MARK: 核心
        TrainingPlanPreset(title: "腹肌雕刻", subtitle: "上下腹 + 腹斜肌全覆盖", category: .core, level: "入门", durationMin: 20, items: [
            .init(nameEn: "Hanging Leg Raise", setsReps: "3 组 × 12 次"),
            .init(nameEn: "Curl up", setsReps: "3 组 × 15 次"),
            .init(nameEn: "Russian Twist", setsReps: "3 组 × 20 次"),
            .init(nameEn: "Front Plank", setsReps: "3 组 × 45 秒"),
        ]),
        TrainingPlanPreset(title: "核心稳定", subtitle: "抗旋抗屈，保护腰椎", category: .core, level: "入门", durationMin: 18, items: [
            .init(nameEn: "Front Plank", setsReps: "3 组 × 45 秒"),
            .init(nameEn: "Lateral Side Plank", setsReps: "3 组 × 30 秒/侧"),
            .init(nameEn: "Dead Bug", setsReps: "3 组 × 12 次"),
            .init(nameEn: "Shoulder Tap", setsReps: "3 组 × 20 次"),
        ]),
        TrainingPlanPreset(title: "进阶核心挑战", subtitle: "悬垂 + 静力，强化深层核心", category: .core, level: "进阶", durationMin: 22, items: [
            .init(nameEn: "Hanging Leg Raise", setsReps: "4 组 × 12 次"),
            .init(nameEn: "L-sit on Floor", setsReps: "4 组 × 20 秒"),
            .init(nameEn: "V Up", setsReps: "3 组 × 15 次"),
            .init(nameEn: "Russian Twist", setsReps: "3 组 × 24 次"),
        ]),
        // MARK: 手臂
        TrainingPlanPreset(title: "二三头围度", subtitle: "弯举 + 下压，撑满袖口", category: .arms, level: "入门", durationMin: 30, items: [
            .init(nameEn: "Barbell Curl", setsReps: "4 组 × 10 次"),
            .init(nameEn: "Dumbbell Seated Hammer Curl", setsReps: "3 组 × 12 次"),
            .init(nameEn: "Triceps Press", setsReps: "4 组 × 12 次"),
            .init(nameEn: "EZ Barbell Lying Triceps Extension", setsReps: "3 组 × 12 次"),
        ]),
        TrainingPlanPreset(title: "二头集中弯举", subtitle: "多角度弯举，堆叠二头围度", category: .arms, level: "入门", durationMin: 25, items: [
            .init(nameEn: "Barbell Curl", setsReps: "4 组 × 10 次"),
            .init(nameEn: "Dumbbell Biceps Curl", setsReps: "3 组 × 12 次"),
            .init(nameEn: "Cable Hammer Curl", setsReps: "3 组 × 12 次"),
            .init(nameEn: "EZ Barbell Preacher Curl", setsReps: "3 组 × 12 次"),
        ]),
        TrainingPlanPreset(title: "三头围度强化", subtitle: "下压 + 臂屈伸，撑满后臂", category: .arms, level: "进阶", durationMin: 28, items: [
            .init(nameEn: "EZ Barbell Lying Triceps Extension", setsReps: "4 组 × 10 次"),
            .init(nameEn: "Triceps Press", setsReps: "4 组 × 12 次"),
            .init(nameEn: "Triceps Dips Floor", setsReps: "3 组 × 力竭"),
            .init(nameEn: "Triceps Dip", setsReps: "3 组 × 力竭"),
        ]),
    ]

    /// 某分类下的训练计划：入门排在进阶前面，同档保持录入顺序。
    static func presets(in category: MuscleCategory) -> [TrainingPlanPreset] {
        all.enumerated()
            .filter { $0.element.category == category }
            .sorted { a, b in
                let ra = levelRank(a.element.level), rb = levelRank(b.element.level)
                return ra == rb ? a.offset < b.offset : ra < rb
            }
            .map { $0.element }
    }

    /// 难度档排序权重：入门 < 进阶 < 其他。
    private static func levelRank(_ level: String) -> Int {
        switch level {
        case "入门": return 0
        case "进阶": return 1
        default:    return 2
        }
    }
}

// MARK: - 训练计划详情页

struct TrainingPlanDetailView: View {
    let preset: TrainingPlanPreset

    @StateObject private var profileStore = ProfileStore()
    private var isFemale: Bool { profileStore.profile.gender == .female }
    private var accent: Color { .exerciseOrange }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                headerCard
                exerciseList
                disclaimer
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .background(Color.appBg.ignoresSafeArea())
        .navigationTitle(preset.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text(preset.title)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(.textPrimary)
                Text(preset.subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    statChip(icon: "figure.strengthtraining.traditional", text: preset.category.displayName)
                    statChip(icon: "chart.bar.fill", text: preset.level)
                    statChip(icon: "clock.fill", text: "约 \(preset.durationMin) 分钟")
                    statChip(icon: "list.bullet", text: "\(preset.exercises.count) 个动作")
                }
            }
        }
    }

    private func statChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            Text(text).font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(accent)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(accent.opacity(0.10))
        .clipShape(Capsule())
    }

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "动作清单") {
                Text("按顺序完成")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textMuted)
            }

            LazyVStack(spacing: 8) {
                ForEach(Array(preset.items.enumerated()), id: \.element.id) { index, item in
                    if let exercise = item.exercise {
                        NavigationLink {
                            ExerciseDetailView(exercise: exercise, isFemale: isFemale)
                        } label: {
                            HStack(spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(accent)
                                    .frame(width: 22, height: 22)
                                    .background(accent.opacity(0.12))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 6) {
                                    ExerciseRow(exercise: exercise, accent: accent, isFemale: isFemale)
                                    HStack(spacing: 5) {
                                        Image(systemName: "repeat")
                                            .font(.system(size: 10, weight: .semibold))
                                        Text(item.setsReps)
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundColor(accent)
                                    .padding(.leading, 2)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var disclaimer: some View {
        Text("训练计划仅供参考，请量力而行，必要时在专业指导下进行")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.textMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
    }
}
