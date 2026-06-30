// TrainingPlanPresets.swift
// 小工具 · 训练计划：力量训练「训练计划」预设（顶部第一个卡片）+ 计划详情页。
// 每个预设引用 TrainingPlanData 内置动作（按英文名），并附建议组次。

import SwiftUI
import UIKit

// MARK: - 预设训练计划

struct TrainingPlanItem: Identifiable {
    let id = UUID()
    let nameEn: String?
    let title: String?
    let setsReps: String
    let restSec: Int?         // 组间歇（秒）；热身/拉伸动作可为空
    let note: String?

    init(nameEn: String, setsReps: String, restSec: Int) {
        self.nameEn = nameEn
        self.title = nil
        self.setsReps = setsReps
        self.restSec = restSec
        self.note = nil
    }

    init(title: String, setsReps: String, restSec: Int? = nil, note: String? = nil) {
        self.nameEn = nil
        self.title = title
        self.setsReps = setsReps
        self.restSec = restSec
        self.note = note
    }

    var exercise: Exercise? {
        guard let nameEn else { return nil }
        return TrainingPlanData.exercise(nameEn)
    }

    var displayName: String {
        exercise?.name ?? title ?? nameEn ?? ""
    }

    var displaySubtitle: String? {
        if let exercise { return exercise.nameEn }
        return note
    }

    /// 组间歇展示文案：≥60s 折算成「1 分 30 秒」式，否则「45 秒」。
    var restText: String? {
        guard let restSec else { return nil }
        if restSec >= 60 {
            let m = restSec / 60, s = restSec % 60
            return s == 0 ? "\(m) 分钟" : "\(m) 分 \(s) 秒"
        }
        return "\(restSec) 秒"
    }

    var compactRestText: String? {
        guard let restSec else { return nil }
        if restSec >= 60 {
            let m = restSec / 60, s = restSec % 60
            return s == 0 ? "\(m)分钟" : "\(m)分\(s)秒"
        }
        return "\(restSec)秒"
    }

    var setCountText: String? {
        let compact = setsReps.replacingOccurrences(of: " ", with: "")
        guard let range = compact.range(of: "组") else { return nil }
        let value = String(compact[..<range.upperBound])
        return value.contains(where: \.isNumber) ? value : nil
    }

    var perSetText: String {
        if let range = setsReps.range(of: "×") {
            return String(setsReps[range.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let range = setsReps.range(of: "，") {
            return String(setsReps[range.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return setsReps.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct TrainingPlanSection: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let items: [TrainingPlanItem]
}

struct TrainingPlanPreset: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String          // 一句话目标
    let category: MuscleCategory
    let level: String             // 入门 / 进阶
    let durationMin: Int          // 预计时长
    let items: [TrainingPlanItem]
    let difficultyStars: Int?
    let intensityStars: Int?
    let audience: String?
    let sections: [TrainingPlanSection]
    let tips: [String]

    init(title: String, subtitle: String, category: MuscleCategory, level: String,
         durationMin: Int, items: [TrainingPlanItem],
         difficultyStars: Int? = nil, intensityStars: Int? = nil, audience: String? = nil,
         warmup: [TrainingPlanItem] = [], warmupSubtitle: String = "约 5 分钟",
         additionalWarmupSections: [TrainingPlanSection] = [],
         cooldown: [TrainingPlanItem] = [], cooldownSubtitle: String = "约 4 分钟",
         tips: [String] = []) {
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.level = level
        self.durationMin = durationMin
        self.items = items
        self.difficultyStars = difficultyStars
        self.intensityStars = intensityStars
        self.audience = audience
        self.tips = tips

        var sections: [TrainingPlanSection] = []
        if !warmup.isEmpty {
            sections.append(TrainingPlanSection(title: "热身", subtitle: warmupSubtitle, items: warmup))
        }
        sections.append(contentsOf: additionalWarmupSections)
        sections.append(TrainingPlanSection(title: "正式训练", subtitle: "按顺序完成", items: items))
        if !cooldown.isEmpty {
            sections.append(TrainingPlanSection(title: "拉伸放松", subtitle: cooldownSubtitle, items: cooldown))
        }
        self.sections = sections
    }

    var exercises: [Exercise] { items.compactMap { $0.exercise } }
    var stepCount: Int { sections.reduce(0) { $0 + $1.items.count } }
    var hasRatings: Bool { difficultyStars != nil || intensityStars != nil || audience != nil }
}

enum TrainingPlanPresets {
    // 编排原则（按健身常识）：大重量复合动作排在最前（精力最足时做），孤立/辅助收尾；
    // 增肌取向，工作组次数 6–12 次（非耐力组）；组间歇按强度递减——
    // 大复合 90–120s，中等 60–90s，孤立/核心 45–60s。
    private static let standardChestWarmup: [TrainingPlanItem] = [
        .init(title: "开合跳", setsReps: "30 秒"),
        .init(title: "手臂绕环（前、后）", setsReps: "各 20 圈"),
        .init(title: "扩胸运动", setsReps: "20 次"),
        .init(title: "肩胛俯卧撑", setsReps: "15 次"),
        .init(title: "平板支撑", setsReps: "30 秒"),
    ]

    private static let advancedChestWarmup: [TrainingPlanItem] = [
        .init(title: "开合跳", setsReps: "30 秒"),
        .init(title: "手臂绕环（前、后）", setsReps: "各 20 圈"),
        .init(title: "扩胸运动", setsReps: "20 次"),
        .init(title: "肩胛俯卧撑", setsReps: "15 次"),
        .init(title: "平板支撑", setsReps: "45 秒"),
    ]

    private static let benchPressWarmup = TrainingPlanSection(title: "卧推专项热身", subtitle: "不计入正式训练", items: [
        .init(title: "空杆卧推", setsReps: "15–20 次"),
        .init(title: "正式重量的 50%", setsReps: "8 次"),
        .init(title: "正式重量的 70%", setsReps: "5 次"),
    ])

    private static let standardChestCooldown: [TrainingPlanItem] = [
        .init(title: "门框胸肌拉伸", setsReps: "左右各 30 秒"),
        .init(title: "胸大肌静态拉伸", setsReps: "左右各 30 秒"),
        .init(title: "肩部前侧拉伸", setsReps: "左右各 30 秒"),
        .init(title: "猫牛式拉伸", setsReps: "60 秒"),
    ]

    private static let advancedChestCooldown: [TrainingPlanItem] = standardChestCooldown + [
        .init(title: "胸椎伸展放松", setsReps: "60 秒"),
    ]

    private static let chestTrainingTips: [String] = [
        "每周训练胸部 1–2 次，两次训练间隔至少 48 小时。",
        "每组保持规范动作轨迹，建议保留 1–2 次余力。",
        "结束后完成拉伸，帮助恢复肩关节活动度并缓解胸部紧张。",
    ]

    static let all: [TrainingPlanPreset] = [
        // MARK: 胸
        TrainingPlanPreset(title: "胸部增肌基础", subtitle: "推举打底，全面刺激胸大肌", category: .chest, level: "入门", durationMin: 45, items: [
            .init(nameEn: "Dumbbell Bench Press", setsReps: "4 组 × 8–10 次", restSec: 90),
            .init(nameEn: "Dumbbell Incline Bench Press", setsReps: "4 组 × 8–10 次", restSec: 90),
            .init(nameEn: "Cable Crossover", setsReps: "3 组 × 12–15 次", restSec: 60),
            .init(nameEn: "Push Ups", setsReps: "3 组，接近力竭（保留 1–2 次余力）", restSec: 60),
        ], difficultyStars: 2, intensityStars: 3, audience: "入门增肌、自由重量训练",
           warmup: standardChestWarmup, cooldown: standardChestCooldown, tips: chestTrainingTips),
        TrainingPlanPreset(title: "徒手胸部塑形", subtitle: "无需器械，在家高效练胸", category: .chest, level: "入门", durationMin: 30, items: [
            .init(nameEn: "Push Ups", setsReps: "4 组 × 10–15 次", restSec: 60),
            .init(nameEn: "Wide Hand Push Up", setsReps: "3 组 × 10–15 次", restSec: 60),
            .init(title: "下斜俯卧撑（双脚抬高）", setsReps: "3 组 × 8–12 次", restSec: 60,
                  note: "暂时完成不了时，可替换为跪姿俯卧撑或上斜俯卧撑"),
            .init(nameEn: "Diamond Push Up", setsReps: "3 组 × 8–10 次", restSec: 60),
        ], difficultyStars: 1, intensityStars: 2, audience: "零器械、新手、居家训练",
           warmup: standardChestWarmup, cooldown: standardChestCooldown,
           tips: ["下斜俯卧撑可按能力替换为跪姿俯卧撑或上斜俯卧撑。"] + chestTrainingTips),
        TrainingPlanPreset(title: "器械胸部训练", subtitle: "稳定发力，更容易找到胸肌感觉", category: .chest, level: "入门", durationMin: 45, items: [
            .init(nameEn: "Lever Chest Press", setsReps: "4 组 × 10 次", restSec: 90),
            .init(title: "上斜器械推胸", setsReps: "3 组 × 10 次", restSec: 90,
                  note: "使用上斜胸推器械，靠背贴稳、路径控制"),
            .init(nameEn: "Lever Pec Deck Fly", setsReps: "3 组 × 12–15 次", restSec: 60),
            .init(nameEn: "Cable Crossover", setsReps: "3 组 × 12–15 次", restSec: 60),
        ], difficultyStars: 2, intensityStars: 3, audience: "健身房新手、减脂训练",
           warmup: standardChestWarmup, cooldown: standardChestCooldown, tips: chestTrainingTips),
        TrainingPlanPreset(title: "胸部进阶强化", subtitle: "提升力量，打造厚实胸肌", category: .chest, level: "进阶", durationMin: 50, items: [
            .init(nameEn: "Barbell Bench Press", setsReps: "5 组 × 5–6 次", restSec: 120),
            .init(nameEn: "Dumbbell Incline Bench Press", setsReps: "4 组 × 8–10 次", restSec: 90),
            .init(nameEn: "Chest Dip", setsReps: "3 组 × 8–10 次", restSec: 75),
            .init(nameEn: "Dumbbell Fly", setsReps: "3 组 × 12–15 次", restSec: 60),
        ], difficultyStars: 4, intensityStars: 5, audience: "力量提升、胸部增肌进阶",
           warmup: advancedChestWarmup, warmupSubtitle: "约 6 分钟",
           additionalWarmupSections: [benchPressWarmup],
           cooldown: advancedChestCooldown, cooldownSubtitle: "约 5 分钟",
           tips: chestTrainingTips),
        // MARK: 肩
        TrainingPlanPreset(title: "圆肩三角肌", subtitle: "前中后束兼顾，撑起肩线", category: .shoulders, level: "进阶", durationMin: 35, items: [
            .init(nameEn: "Dumbbell Seated Shoulder Press", setsReps: "4 组 × 8–10 次", restSec: 90),
            .init(nameEn: "Dumbbell Lateral Raise", setsReps: "4 组 × 12 次", restSec: 60),
            .init(nameEn: "Cable Front Raise", setsReps: "3 组 × 12 次", restSec: 60),
            .init(nameEn: "Prone Y Raise", setsReps: "3 组 × 12 次", restSec: 45),
        ]),
        TrainingPlanPreset(title: "肩部稳定与后束", subtitle: "改善圆肩，强化后链", category: .shoulders, level: "入门", durationMin: 30, items: [
            .init(nameEn: "Barbell Rear Delt Row", setsReps: "3 组 × 12 次", restSec: 75),
            .init(nameEn: "Cable Lateral Raise", setsReps: "3 组 × 12 次", restSec: 60),
            .init(nameEn: "Prone Y Raise", setsReps: "3 组 × 12 次", restSec: 45),
            .init(nameEn: "Resistance Band External Rotation", setsReps: "3 组 × 12 次", restSec: 45),
        ]),
        TrainingPlanPreset(title: "肩部围度塑形", subtitle: "推举打底 + 三向平举", category: .shoulders, level: "入门", durationMin: 30, items: [
            .init(nameEn: "Dumbbell Seated Shoulder Press", setsReps: "4 组 × 10 次", restSec: 90),
            .init(nameEn: "Dumbbell Lateral Raise", setsReps: "4 组 × 12 次", restSec: 60),
            .init(nameEn: "Cable Front Raise", setsReps: "3 组 × 12 次", restSec: 60),
            .init(nameEn: "Barbell Shrug", setsReps: "3 组 × 12 次", restSec: 60),
        ]),
        // MARK: 背
        TrainingPlanPreset(title: "背部宽厚基础", subtitle: "纵向下拉 + 横向划船", category: .back, level: "进阶", durationMin: 45, items: [
            .init(nameEn: "Pull Up", setsReps: "4 组 × 6–8 次", restSec: 120),
            .init(nameEn: "Cable Wide Grip Lat Pulldown", setsReps: "4 组 × 10 次", restSec: 90),
            .init(nameEn: "Cable Seated Row", setsReps: "3 组 × 12 次", restSec: 75),
            .init(nameEn: "Dumbbell Bent Over Row", setsReps: "3 组 × 10 次", restSec: 75),
        ]),
        TrainingPlanPreset(title: "新手友好背部", subtitle: "有辅助也能练出背阔肌", category: .back, level: "入门", durationMin: 35, items: [
            .init(nameEn: "Assisted Pull Up", setsReps: "4 组 × 10 次", restSec: 90),
            .init(nameEn: "Cable Pulldown", setsReps: "3 组 × 12 次", restSec: 75),
            .init(nameEn: "Lever Seated Row", setsReps: "3 组 × 12 次", restSec: 60),
            .init(nameEn: "Hyperextension", setsReps: "3 组 × 12 次", restSec: 45),
        ]),
        TrainingPlanPreset(title: "背部线条划船", subtitle: "多角度划船刻画背沟", category: .back, level: "入门", durationMin: 35, items: [
            .init(nameEn: "Dumbbell Bent Over Row", setsReps: "4 组 × 10 次", restSec: 75),
            .init(nameEn: "Cable Seated Row", setsReps: "3 组 × 12 次", restSec: 75),
            .init(nameEn: "Lever Seated Row", setsReps: "3 组 × 12 次", restSec: 60),
            .init(nameEn: "Hyperextension", setsReps: "3 组 × 12 次", restSec: 45),
        ]),
        // MARK: 腿
        TrainingPlanPreset(title: "下肢力量基础", subtitle: "深蹲硬拉打地基", category: .lower, level: "进阶", durationMin: 50, items: [
            .init(nameEn: "Barbell Back Squat", setsReps: "4 组 × 6–8 次", restSec: 120),
            .init(nameEn: "Dumbbell Romanian Deadlift", setsReps: "3 组 × 10 次", restSec: 90),
            .init(nameEn: "Dumbbell Lunge", setsReps: "3 组 × 10 次/侧", restSec: 75),
            .init(nameEn: "Leg Extension", setsReps: "3 组 × 12 次", restSec: 60),
        ]),
        TrainingPlanPreset(title: "翘臀计划", subtitle: "臀推主导，练出臀线", category: .lower, level: "入门", durationMin: 35, items: [
            .init(nameEn: "Hip Thrusts", setsReps: "4 组 × 12 次", restSec: 90),
            .init(nameEn: "Dumbbell Goblet Squat", setsReps: "3 组 × 12 次", restSec: 75),
            .init(nameEn: "Forward Lunge", setsReps: "3 组 × 10 次/侧", restSec: 60),
            .init(nameEn: "Butt Bridge", setsReps: "3 组 × 12 次", restSec: 45),
        ]),
        TrainingPlanPreset(title: "居家腿臀", subtitle: "无器械，徒手练腿臀", category: .lower, level: "入门", durationMin: 25, items: [
            .init(nameEn: "Air Squat", setsReps: "4 组 × 12 次", restSec: 60),
            .init(nameEn: "Forward Lunge", setsReps: "3 组 × 12 次/侧", restSec: 60),
            .init(nameEn: "Hip Thrusts", setsReps: "3 组 × 12 次", restSec: 60),
            .init(nameEn: "Butt Bridge", setsReps: "3 组 × 12 次", restSec: 45),
        ]),
        // MARK: 核心
        TrainingPlanPreset(title: "腹肌雕刻", subtitle: "上下腹 + 腹斜肌全覆盖", category: .core, level: "入门", durationMin: 20, items: [
            .init(nameEn: "Hanging Leg Raise", setsReps: "3 组 × 12 次", restSec: 60),
            .init(nameEn: "Curl up", setsReps: "3 组 × 12 次", restSec: 45),
            .init(nameEn: "Russian Twist", setsReps: "3 组 × 12 次/侧", restSec: 45),
            .init(nameEn: "Front Plank", setsReps: "3 组 × 45 秒", restSec: 45),
        ]),
        TrainingPlanPreset(title: "核心稳定", subtitle: "抗旋抗屈，保护腰椎", category: .core, level: "入门", durationMin: 18, items: [
            .init(nameEn: "Front Plank", setsReps: "3 组 × 45 秒", restSec: 45),
            .init(nameEn: "Lateral Side Plank", setsReps: "3 组 × 30 秒/侧", restSec: 45),
            .init(nameEn: "Dead Bug", setsReps: "3 组 × 12 次/侧", restSec: 45),
            .init(nameEn: "Shoulder Tap", setsReps: "3 组 × 12 次/侧", restSec: 45),
        ]),
        TrainingPlanPreset(title: "进阶核心挑战", subtitle: "悬垂 + 静力，强化深层核心", category: .core, level: "进阶", durationMin: 22, items: [
            .init(nameEn: "Hanging Leg Raise", setsReps: "4 组 × 12 次", restSec: 60),
            .init(nameEn: "L-sit on Floor", setsReps: "4 组 × 20 秒", restSec: 60),
            .init(nameEn: "V Up", setsReps: "3 组 × 12 次", restSec: 45),
            .init(nameEn: "Russian Twist", setsReps: "3 组 × 12 次/侧", restSec: 45),
        ]),
        // MARK: 手臂
        TrainingPlanPreset(title: "二三头围度", subtitle: "弯举 + 下压，撑满袖口", category: .arms, level: "入门", durationMin: 30, items: [
            .init(nameEn: "Barbell Curl", setsReps: "4 组 × 10 次", restSec: 75),
            .init(nameEn: "EZ Barbell Lying Triceps Extension", setsReps: "4 组 × 10 次", restSec: 75),
            .init(nameEn: "Dumbbell Seated Hammer Curl", setsReps: "3 组 × 12 次", restSec: 60),
            .init(nameEn: "Triceps Press", setsReps: "3 组 × 12 次", restSec: 60),
        ]),
        TrainingPlanPreset(title: "二头集中弯举", subtitle: "多角度弯举，堆叠二头围度", category: .arms, level: "入门", durationMin: 25, items: [
            .init(nameEn: "Barbell Curl", setsReps: "4 组 × 10 次", restSec: 75),
            .init(nameEn: "Dumbbell Biceps Curl", setsReps: "3 组 × 12 次", restSec: 60),
            .init(nameEn: "EZ Barbell Preacher Curl", setsReps: "3 组 × 10 次", restSec: 60),
            .init(nameEn: "Cable Hammer Curl", setsReps: "3 组 × 12 次", restSec: 45),
        ]),
        TrainingPlanPreset(title: "三头围度强化", subtitle: "下压 + 臂屈伸，撑满后臂", category: .arms, level: "进阶", durationMin: 28, items: [
            .init(nameEn: "Triceps Dip", setsReps: "4 组 × 8 次", restSec: 90),
            .init(nameEn: "EZ Barbell Lying Triceps Extension", setsReps: "4 组 × 10 次", restSec: 75),
            .init(nameEn: "Triceps Press", setsReps: "3 组 × 12 次", restSec: 60),
            .init(nameEn: "Triceps Dips Floor", setsReps: "3 组 × 12 次", restSec: 45),
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
                if !preset.tips.isEmpty {
                    tipsCard
                }
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
        CardView(padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(preset.title)
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundColor(.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.86)
                        Text(preset.subtitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(preset.durationMin)")
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundColor(accent)
                        Text("分钟")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.textMuted)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("约 \(preset.durationMin) 分钟"))
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        statChip(icon: "figure.strengthtraining.traditional", text: preset.category.displayName)
                        statChip(icon: "chart.bar.fill", text: preset.level)
                        statChip(icon: "clock.fill", text: "约 \(preset.durationMin) 分钟")
                        statChip(icon: "list.bullet", text: "\(preset.stepCount) 个步骤")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            statChip(icon: "figure.strengthtraining.traditional", text: preset.category.displayName)
                            statChip(icon: "chart.bar.fill", text: preset.level)
                        }
                        HStack(spacing: 8) {
                            statChip(icon: "clock.fill", text: "约 \(preset.durationMin) 分钟")
                            statChip(icon: "list.bullet", text: "\(preset.stepCount) 个步骤")
                        }
                    }
                }

                if preset.hasRatings {
                    ratingPanel
                }
            }
        }
    }

    private func statChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            Text(text).font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.appBg)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.hairline, lineWidth: 1))
    }

    private var ratingPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let difficulty = preset.difficultyStars {
                    ratingCell(title: "难度",
                               summary: difficultySummary,
                               level: difficulty,
                               style: .dots,
                               tint: .textPrimary)
                }
                if let intensity = preset.intensityStars {
                    ratingCell(title: "强度",
                               summary: intensitySummary,
                               level: intensity,
                               style: .bars,
                               tint: accent)
                }
            }

            if let audience = preset.audience, !audience.isEmpty {
                Text("适合人群：\(audience)")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appBg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private enum RatingIndicatorStyle {
        case dots
        case bars
    }

    private func ratingCell(title: String, summary: String, level: Int,
                            style: RatingIndicatorStyle, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.textSecondary)
                Spacer(minLength: 8)
                ratingIndicator(level: level, style: style, tint: tint)
            }

            Text(summary)
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(title) \(min(max(level, 0), 5))/5，\(summary)"))
    }

    @ViewBuilder
    private func ratingIndicator(level: Int, style: RatingIndicatorStyle, tint: Color) -> some View {
        let value = min(max(level, 0), 5)
        switch style {
        case .dots:
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(index < value ? tint : Color.textMuted.opacity(0.34))
                        .frame(width: 8, height: 8)
                }
            }
        case .bars:
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(index < value ? tint : Color.textMuted.opacity(0.28))
                        .frame(width: 6, height: 10 + CGFloat(index) * 3)
                }
            }
        }
    }

    private var difficultySummary: String {
        guard let audience = preset.audience, !audience.isEmpty else { return preset.level }
        let parts = audience
            .split(separator: "、")
            .prefix(2)
            .map { $0.replacingOccurrences(of: "训练", with: "") }
        return parts.isEmpty ? preset.level : parts.joined(separator: " · ")
    }

    private var intensitySummary: String {
        let label = DifficultyScale.label(preset.intensityStars ?? 1)
        let rest = preset.items.compactMap(\.restSec).first
        guard let rest else { return label }
        return "\(label) · 组间 \(rest) 秒"
    }

    private var exerciseList: some View {
        VStack(spacing: 18) {
            ForEach(preset.sections) { section in
                planSection(section)
            }
        }
    }

    @ViewBuilder
    private func planSection(_ section: TrainingPlanSection) -> some View {
        if section.title == "正式训练" {
            mainTrainingSection(section)
        } else {
            compactPlanSection(section)
        }
    }

    private func mainTrainingSection(_ section: TrainingPlanSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: section.title) {
                Text("\(section.items.count) 个动作")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textMuted)
            }

            LazyVStack(spacing: 12) {
                ForEach(section.items) { item in
                    trainingPlanRow(item)
                }
            }
        }
    }

    private func trainingPlanRow(_ item: TrainingPlanItem) -> some View {
        Group {
            if let exercise = item.exercise {
                NavigationLink {
                    ExerciseDetailView(exercise: exercise, isFemale: isFemale)
                } label: {
                    trainingPlanCardContent(item, exercise: exercise)
                }
                .buttonStyle(.plain)
            } else {
                trainingPlanCardContent(item, exercise: nil)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 154, alignment: .leading)
        .background(Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.hairline, lineWidth: 1)
        )
    }

    private func trainingPlanCardContent(_ item: TrainingPlanItem, exercise: Exercise?) -> some View {
        HStack(spacing: 14) {
            planThumbnail(exercise: exercise)

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayName)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    if let subtitle = item.displaySubtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.textMuted)
                            .lineLimit(1)
                    }
                }

                if let exercise {
                    workoutTags(for: exercise)
                }

                Spacer(minLength: 0)
                Text(trainingMetaText(for: item))
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func planThumbnail(exercise: Exercise?) -> some View {
        if let exercise, let illustration = UIImage(named: exercise.image) {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(accent.opacity(0.08))
                .frame(width: 136, height: 130)
                .overlay {
                    Image(uiImage: illustration)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 136, height: 130)
                        .clipped()
                }
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(accent.opacity(0.10))
                .frame(width: 136, height: 130)
                .overlay {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(accent)
                }
        }
    }

    private func workoutTags(for exercise: Exercise) -> some View {
        let primary = exercise.primaryMuscles.first
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 5) {
                if let primary {
                    ExerciseTag(title: primary, foreground: accent, background: accent.opacity(0.10))
                }
                ExerciseTag(title: exercise.type)
                DifficultyChip(level: exercise.difficulty)
            }

            HStack(spacing: 5) {
                if let primary {
                    ExerciseTag(title: primary, foreground: accent, background: accent.opacity(0.10))
                }
                ExerciseTag(title: exercise.type)
            }
        }
    }

    private func trainingMetaText(for item: TrainingPlanItem) -> String {
        var values: [String] = []
        if let setCount = item.setCountText {
            values.append(setCount)
        }
        values.append(item.perSetText)
        if let rest = item.compactRestText {
            values.append("休息 \(rest)")
        }
        return values.joined(separator: " · ")
    }

    private func compactPlanSection(_ section: TrainingPlanSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: section.title) {
                if let subtitle = section.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textMuted)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(section.items) { item in
                        compactPlanCard(item)
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactPlanCard(_ item: TrainingPlanItem) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(item.displayName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)

            Text(item.setsReps)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.88)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: compactPlanCardWidth(for: item.displayName), height: 76, alignment: .leading)
        .background(Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.hairline, lineWidth: 1)
        )
    }

    private func compactPlanCardWidth(for title: String) -> CGFloat {
        switch title.count {
        case ...4: return 124
        case 5...7: return 146
        case 8...10: return 174
        default: return 206
        }
    }

    private var tipsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("训练建议")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.textPrimary)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(preset.tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 5, weight: .bold))
                                .foregroundColor(accent)
                                .padding(.top, 7)
                            Text(tip)
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
        Text("训练计划仅供参考，请量力而行，必要时在专业指导下进行")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.textMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
    }
}
