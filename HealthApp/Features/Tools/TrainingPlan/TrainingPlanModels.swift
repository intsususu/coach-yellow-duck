// TrainingPlanModels.swift
// 小工具 · 训练计划：动作库数据模型 + 内置内容（7 类共 92 个动作）。
// 数据源 docs/fitness/index.md，由 scratchpad/gen_exercises.py 解析生成（见 docs/tasks/训练计划重构/TP01-数据层.md）。
// 视频字段为占位（仓库暂无 mp4），素材到位后接入；演示性别按个人资料自动匹配（见 TP02/TP03）。

import SwiftUI
import UIKit

// MARK: - 顶部三大类

enum TrainingMode: String, CaseIterable, Identifiable {
    case strength, stretch, hiit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .strength: return "力量训练"
        case .stretch:  return "拉伸"
        case .hiit:     return "HIIT"
        }
    }
}

// MARK: - 训练分类（7 类）

enum MuscleCategory: String, CaseIterable, Identifiable {
    case core, chest, back, shoulders, arms, lower

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .core:       return "核心"
        case .chest:      return "胸"
        case .back:       return "背"
        case .shoulders:  return "肩"
        case .arms:       return "手臂"
        case .lower:      return "腿"
        }
    }
}

// MARK: - 肌群（用于解剖图高亮 / 按肌群筛选）
// rawValue 即 slug，对齐 react-native-body-highlighter（MIT），便于 TP04 复用其人体 path。

enum MuscleGroup: String, CaseIterable, Identifiable {
    case abs
    case obliques
    case chest
    case biceps
    case triceps
    case forearm
    case frontDeltoids = "front-deltoids"
    case deltoids
    case rearDeltoids = "rear-deltoids"
    case trapezius
    case upperBack = "upper-back"
    case lowerBack = "lower-back"
    case quadriceps
    case hamstring
    case gluteal
    case calves
    case adductor
    case abductors
    case neck

    var id: String { rawValue }
    var slug: String { rawValue }

    var displayName: String {
        switch self {
        case .abs:           return "腹肌"
        case .obliques:      return "腹斜肌"
        case .chest:         return "胸大肌"
        case .biceps:        return "肱二头肌"
        case .triceps:       return "肱三头肌"
        case .forearm:       return "前臂"
        case .frontDeltoids: return "三角肌前束"
        case .deltoids:      return "三角肌中束"
        case .rearDeltoids:  return "三角肌后束"
        case .trapezius:     return "斜方肌"
        case .upperBack:     return "背阔肌"
        case .lowerBack:     return "下背"
        case .quadriceps:    return "股四头肌"
        case .hamstring:     return "腘绳肌"
        case .gluteal:       return "臀大肌"
        case .calves:        return "小腿"
        case .adductor:      return "内收肌"
        case .abductors:     return "外展肌"
        case .neck:          return "颈部"
        }
    }
}

// MARK: - 一个训练动作

struct Exercise: Identifiable {
    let id = UUID()
    let name: String                 // 中文名
    let nameEn: String               // 英文名
    let category: MuscleCategory     // 所属训练分类
    let primaryMuscles: [String]     // 主练肌群（展示用中文，首项为主）
    let muscleGroups: [MuscleGroup]  // 解剖图高亮 / 筛选用，主练在前
    let type: String                 // 动作类型（如「卧推/胸推」「下拉」）
    let difficulty: Int              // 难度 1–5
    let maleVideo: String            // 男版演示视频文件名（占位期可空）
    let femaleVideo: String          // 女版演示视频文件名（占位期可空）
    let image: String                // 演示图（Assets 资源名，默认与英文名一致）
    let points: [String]             // 动作要点（index.md 无，暂空，详情页降级）
    let setsReps: String             // 建议组数 × 次数（暂空）

    init(_ name: String, _ nameEn: String, category: MuscleCategory,
         primaryMuscles: [String], muscleGroups: [MuscleGroup],
         type: String, difficulty: Int,
         maleVideo: String, femaleVideo: String,
         image: String? = nil,
         points: [String] = [], setsReps: String = "") {
        self.name = name
        self.nameEn = nameEn
        self.category = category
        self.primaryMuscles = primaryMuscles
        self.muscleGroups = muscleGroups
        self.type = type
        self.difficulty = difficulty
        self.maleVideo = maleVideo
        self.femaleVideo = femaleVideo
        self.image = image ?? nameEn
        self.points = points
        self.setsReps = setsReps
    }

    /// 是否有演示图（Assets 中存在同名资源）。
    var hasImage: Bool { UIImage(named: image) != nil }

    /// 按性别取演示视频文件名（女版优先用 female，其余用 male）。占位期可能为空。
    func video(female: Bool) -> String {
        female ? femaleVideo : maleVideo
    }

    var hasVideo: Bool { !maleVideo.isEmpty || !femaleVideo.isEmpty }
}

// MARK: - 查询接口（供 TP02 主页 / TP04 解剖图调用）

extension TrainingPlanData {
    /// 某分类下的全部动作（保持内置顺序）。
    static func exercises(in category: MuscleCategory) -> [Exercise] {
        exercises.filter { $0.category == category }
    }

    /// 练某肌群的全部动作。
    static func exercises(for muscle: MuscleGroup) -> [Exercise] {
        exercises.filter { $0.muscleGroups.contains(muscle) }
    }

    /// 关键词搜索：匹配中文名 / 英文名 / 主练肌群 / 类型（忽略大小写）。
    static func search(_ keyword: String) -> [Exercise] {
        let key = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return [] }
        return exercises.filter { ex in
            ex.name.lowercased().contains(key)
                || ex.nameEn.lowercased().contains(key)
                || ex.type.lowercased().contains(key)
                || ex.primaryMuscles.contains { $0.lowercased().contains(key) }
        }
    }

    /// 按英文名精确查找动作（供训练计划预设引用）。
    static func exercise(_ nameEn: String) -> Exercise? {
        exercises.first { $0.nameEn == nameEn }
    }

    /// 某分类下出现的动作类型（按首次出现顺序去重），供类型筛选 chips 使用。
    static func types(in category: MuscleCategory) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for ex in exercises(in: category) where seen.insert(ex.type).inserted {
            result.append(ex.type)
        }
        return result
    }
}

// MARK: - 内置内容（76 个，对齐 docs/fitness/力量训练.md：核心16/胸13/背13/肩13/手臂9/腿12）
// 演示图取自 docs/fitness/strength-tranning-images，已导入 Assets（资源名 = 英文名）。

enum TrainingPlanData {
    static let exercises: [Exercise] = [
        // MARK: core (16)
        Exercise("罗马椅举腿", "Captains Chair Leg Raise", category: .core,
                 primaryMuscles: ["腹直肌", "髂腰肌"], muscleGroups: [.abs],
                 type: "举腿/屈髋", difficulty: 2,
                 maleVideo: "Captains Chair Leg Raise.mp4", femaleVideo: "Captains Chair Leg Raise.mp4"),
        Exercise("死虫式", "Dead Bug", category: .core,
                 primaryMuscles: ["腹横肌", "腹直肌"], muscleGroups: [.abs],
                 type: "举腿/屈髋", difficulty: 2,
                 maleVideo: "Dead-Bug.mp4", femaleVideo: "Dead-Bug.mp4"),
        Exercise("悬垂举腿", "Hanging Leg Raise", category: .core,
                 primaryMuscles: ["腹直肌", "髂腰肌"], muscleGroups: [.abs],
                 type: "举腿/屈髋", difficulty: 3,
                 maleVideo: "Hanging Leg Raise.mp4", femaleVideo: "Hanging Leg Raise.mp4"),
        Exercise("仰卧举腿", "Lying Leg Raise", category: .core,
                 primaryMuscles: ["腹直肌", "髂腰肌"], muscleGroups: [.abs],
                 type: "举腿/屈髋", difficulty: 2,
                 maleVideo: "Lying-Leg-Raise.mp4", femaleVideo: "Lying-Leg-Raise.mp4"),
        Exercise("卷腹起身", "Curl up", category: .core,
                 primaryMuscles: ["腹直肌"], muscleGroups: [.abs],
                 type: "卷腹", difficulty: 2,
                 maleVideo: "Curl-up.mp4", femaleVideo: "Curl-up.mp4"),
        Exercise("下斜卷腹", "Decline Crunch", category: .core,
                 primaryMuscles: ["腹直肌"], muscleGroups: [.abs],
                 type: "卷腹", difficulty: 3,
                 maleVideo: "Decline-Crunch.mp4", femaleVideo: "Decline-Crunch.mp4"),
        Exercise("反向卷腹", "Reverse Crunch", category: .core,
                 primaryMuscles: ["腹直肌"], muscleGroups: [.abs],
                 type: "卷腹", difficulty: 2,
                 maleVideo: "Reverse-Crunch.mp4", femaleVideo: "Reverse-Crunch.mp4"),
        Exercise("抱膝卷腹", "Tuck Crunch", category: .core,
                 primaryMuscles: ["腹直肌"], muscleGroups: [.abs],
                 type: "卷腹", difficulty: 2,
                 maleVideo: "Tuck-Crunch.mp4", femaleVideo: "Tuck-Crunch.mp4"),
        Exercise("转体卷腹", "Twisting Crunch", category: .core,
                 primaryMuscles: ["腹内外斜肌"], muscleGroups: [.obliques],
                 type: "卷腹", difficulty: 2,
                 maleVideo: "Twisting-Crunch.mp4", femaleVideo: "Twisting-Crunch.mp4"),
        Exercise("V 字卷腹", "V Up", category: .core,
                 primaryMuscles: ["腹直肌"], muscleGroups: [.abs],
                 type: "卷腹", difficulty: 2,
                 maleVideo: "V-Up.mp4", femaleVideo: "V-Up.mp4"),
        Exercise("正面平板支撑", "Front Plank", category: .core,
                 primaryMuscles: ["腹横肌", "腹直肌"], muscleGroups: [.abs],
                 type: "平板支撑", difficulty: 2,
                 maleVideo: "Front-Plank.mp4", femaleVideo: "Front-Plank.mp4"),
        Exercise("侧向侧平板支撑", "Lateral Side Plank", category: .core,
                 primaryMuscles: ["腹内外斜肌"], muscleGroups: [.obliques],
                 type: "平板支撑", difficulty: 2,
                 maleVideo: "Lateral-Side-Plank.mp4", femaleVideo: "Lateral-Side-Plank.mp4"),
        Exercise("俄罗斯转体", "Russian Twist", category: .core,
                 primaryMuscles: ["腹内外斜肌"], muscleGroups: [.obliques],
                 type: "转体/抗旋", difficulty: 2,
                 maleVideo: "Russian-Twist.mp4", femaleVideo: "Russian-Twist.mp4"),
        Exercise("肩部轻触", "Shoulder Tap", category: .core,
                 primaryMuscles: ["腹直肌"], muscleGroups: [.abs],
                 type: "肩触/支撑", difficulty: 2,
                 maleVideo: "Shoulder-Tap.mp4", femaleVideo: "Shoulder-Tap.mp4"),
        Exercise("地面 L 坐支撑", "L-sit on Floor", category: .core,
                 primaryMuscles: ["核心稳定肌群", "肩胛稳定肌群"], muscleGroups: [.abs, .upperBack],
                 type: "坐姿支撑(L/V-sit)", difficulty: 4,
                 maleVideo: "L-sit on Floor.mp4", femaleVideo: "L-sit on Floor.mp4"),
        Exercise("壶铃仰卧起坐", "Kettlebell Sit Up", category: .core,
                 primaryMuscles: ["腹直肌"], muscleGroups: [.abs],
                 type: "仰卧起坐", difficulty: 3,
                 maleVideo: "Kettlebell Sit Up.mp4", femaleVideo: "Kettlebell Sit Up.mp4"),
        // MARK: chest (13)
        Exercise("胸部臂屈伸", "Chest Dip", category: .chest,
                 primaryMuscles: ["胸大肌"], muscleGroups: [.chest],
                 type: "臂屈伸(Dip)", difficulty: 3,
                 maleVideo: "Chest Dip.mp4", femaleVideo: "Chest Dip.mp4"),
        Exercise("肱三头肌臂屈伸", "Triceps Dip", category: .chest,
                 primaryMuscles: ["肱三头肌"], muscleGroups: [.triceps],
                 type: "臂屈伸(Dip)", difficulty: 3,
                 maleVideo: "Triceps-Dip.mp4", femaleVideo: "Triceps-Dip.mp4"),
        Exercise("杠铃卧推", "Barbell Bench Press", category: .chest,
                 primaryMuscles: ["胸大肌"], muscleGroups: [.chest],
                 type: "卧推/胸推", difficulty: 3,
                 maleVideo: "", femaleVideo: ""),
        Exercise("哑铃卧推", "Dumbbell Bench Press", category: .chest,
                 primaryMuscles: ["胸大肌"], muscleGroups: [.chest],
                 type: "卧推/胸推", difficulty: 3,
                 maleVideo: "Dumbbell-Bench-Press.mp4", femaleVideo: "Dumbbell-Bench-Press.mp4"),
        Exercise("哑铃上斜卧推", "Dumbbell Incline Bench Press", category: .chest,
                 primaryMuscles: ["胸大肌"], muscleGroups: [.chest],
                 type: "卧推/胸推", difficulty: 3,
                 maleVideo: "Dumbbell-Incline-Bench-Press.mp4", femaleVideo: "Dumbbell-Incline-Bench-Press.mp4"),
        Exercise("器械胸推", "Lever Chest Press", category: .chest,
                 primaryMuscles: ["胸大肌"], muscleGroups: [.chest],
                 type: "卧推/胸推", difficulty: 3,
                 maleVideo: "Lever Chest Press.mp4", femaleVideo: "Lever Chest Press.mp4"),
        Exercise("壶铃推起", "Kettlebell Press Up", category: .chest,
                 primaryMuscles: ["胸大肌"], muscleGroups: [.chest],
                 type: "卧推/胸推", difficulty: 3,
                 maleVideo: "Kettlebell Press Up.mp4", femaleVideo: "Kettlebell Press Up.mp4"),
        Exercise("绳索交叉夹胸", "Cable Crossover", category: .chest,
                 primaryMuscles: ["胸大肌"], muscleGroups: [.chest],
                 type: "飞鸟/夹胸", difficulty: 2,
                 maleVideo: "Cable Crossover.mp4", femaleVideo: "Cable Crossover.mp4"),
        Exercise("哑铃飞鸟", "Dumbbell Fly", category: .chest,
                 primaryMuscles: ["胸大肌"], muscleGroups: [.chest],
                 type: "飞鸟/夹胸", difficulty: 3,
                 maleVideo: "Dumbbell-Fly.mp4", femaleVideo: "Dumbbell-Fly.mp4"),
        Exercise("器械蝴蝶机夹胸", "Lever Pec Deck Fly", category: .chest,
                 primaryMuscles: ["胸大肌"], muscleGroups: [.chest],
                 type: "飞鸟/夹胸", difficulty: 2,
                 maleVideo: "Lever Pec Deck Fly.mp4", femaleVideo: "Lever Pec Deck Fly.mp4"),
        Exercise("钻石俯卧撑", "Diamond Push Up", category: .chest,
                 primaryMuscles: ["胸大肌"], muscleGroups: [.chest],
                 type: "俯卧撑", difficulty: 2,
                 maleVideo: "Diamond Push Up.mp4", femaleVideo: "Diamond Push Up.mp4"),
        Exercise("俯卧撑", "Push Ups", category: .chest,
                 primaryMuscles: ["胸大肌"], muscleGroups: [.chest],
                 type: "俯卧撑", difficulty: 2,
                 maleVideo: "Push Ups.mp4", femaleVideo: "Push Ups.mp4"),
        Exercise("宽距俯卧撑", "Wide Hand Push Up", category: .chest,
                 primaryMuscles: ["胸大肌"], muscleGroups: [.chest],
                 type: "俯卧撑", difficulty: 2,
                 maleVideo: "Wide-Hand-Push-Up.mp4", femaleVideo: "Wide-Hand-Push-Up.mp4"),
        // MARK: back (13)
        Exercise("辅助引体向上", "Assisted Pull Up", category: .back,
                 primaryMuscles: ["背阔肌"], muscleGroups: [.upperBack],
                 type: "引体向上", difficulty: 3,
                 maleVideo: "Assisted-Pull-Up.mp4", femaleVideo: "Assisted-Pull-Up.mp4"),
        Exercise("反手引体向上", "Chin Up", category: .back,
                 primaryMuscles: ["背阔肌"], muscleGroups: [.upperBack],
                 type: "引体向上", difficulty: 3,
                 maleVideo: "Chin Up.mp4", femaleVideo: "Chin Up.mp4"),
        Exercise("引体向上", "Pull Up", category: .back,
                 primaryMuscles: ["背阔肌"], muscleGroups: [.upperBack],
                 type: "引体向上", difficulty: 3,
                 maleVideo: "Pull-Up.mp4", femaleVideo: "Pull-Up.mp4"),
        Exercise("杠铃俯身划船", "Barbell Bent Over Row", category: .back,
                 primaryMuscles: ["背阔肌", "菱形肌"], muscleGroups: [.upperBack],
                 type: "划船", difficulty: 3,
                 maleVideo: "Barbell-Bent-Over-Row.mp4", femaleVideo: "Barbell-Bent-Over-Row.mp4"),
        Exercise("绳索坐姿划船", "Cable Seated Row", category: .back,
                 primaryMuscles: ["背阔肌", "菱形肌"], muscleGroups: [.upperBack],
                 type: "划船", difficulty: 3,
                 maleVideo: "Cable Seated Row.mp4", femaleVideo: "Cable Seated Row.mp4"),
        Exercise("哑铃俯身划船", "Dumbbell Bent Over Row", category: .back,
                 primaryMuscles: ["背阔肌", "菱形肌"], muscleGroups: [.upperBack],
                 type: "划船", difficulty: 3,
                 maleVideo: "Dumbbell-Bent-Over-Row.mp4", femaleVideo: "Dumbbell-Bent-Over-Row.mp4"),
        Exercise("反向划船", "Inverted Row", category: .back,
                 primaryMuscles: ["背阔肌", "菱形肌"], muscleGroups: [.upperBack],
                 type: "划船", difficulty: 3,
                 maleVideo: "Inverted Row.mp4", femaleVideo: "Inverted Row.mp4"),
        Exercise("器械坐姿划船", "Lever Seated Row", category: .back,
                 primaryMuscles: ["背阔肌", "菱形肌"], muscleGroups: [.upperBack],
                 type: "划船", difficulty: 3,
                 maleVideo: "Lever Seated Row.mp4", femaleVideo: "Lever Seated Row.mp4"),
        Exercise("壶铃俯身划船", "Kettlebell Bent Over Row", category: .back,
                 primaryMuscles: ["背阔肌", "菱形肌"], muscleGroups: [.upperBack],
                 type: "划船", difficulty: 3,
                 maleVideo: "Kettlebell Bent Over Row.mp4", femaleVideo: "Kettlebell Bent Over Row.mp4"),
        Exercise("壶铃双臂划船", "Kettlebell Two Arm Row", category: .back,
                 primaryMuscles: ["背阔肌", "菱形肌"], muscleGroups: [.upperBack],
                 type: "划船", difficulty: 3,
                 maleVideo: "Kettlebell Two Arm Row.mp4", femaleVideo: "Kettlebell Two Arm Row.mp4"),
        Exercise("绳索下拉", "Cable Pulldown", category: .back,
                 primaryMuscles: ["背阔肌"], muscleGroups: [.upperBack],
                 type: "下拉", difficulty: 3,
                 maleVideo: "Cable Pulldown.mp4", femaleVideo: "Cable Pulldown.mp4"),
        Exercise("绳索宽握背阔肌下拉", "Cable Wide Grip Lat Pulldown", category: .back,
                 primaryMuscles: ["背阔肌"], muscleGroups: [.upperBack],
                 type: "下拉", difficulty: 3,
                 maleVideo: "Cable Wide Grip Lat Pulldown.mp4", femaleVideo: "Cable Wide Grip Lat Pulldown.mp4"),
        Exercise("背伸", "Hyperextension", category: .back,
                 primaryMuscles: ["竖脊肌"], muscleGroups: [.lowerBack],
                 type: "背部伸展", difficulty: 2,
                 maleVideo: "Hyperextension.mp4", femaleVideo: "Hyperextension.mp4"),
        // MARK: shoulders (13)
        Exercise("绳索前平举", "Cable Front Raise", category: .shoulders,
                 primaryMuscles: ["三角肌前束"], muscleGroups: [.frontDeltoids],
                 type: "前平举", difficulty: 2,
                 maleVideo: "Cable Front Raise.mp4", femaleVideo: "Cable Front Raise.mp4"),
        Exercise("哑铃前平举", "Dumbbell Front Raise", category: .shoulders,
                 primaryMuscles: ["三角肌前束"], muscleGroups: [.frontDeltoids],
                 type: "前平举", difficulty: 3,
                 maleVideo: "Dumbbell Front Raise.mp4", femaleVideo: "Dumbbell Front Raise.mp4"),
        Exercise("绳索侧平举", "Cable Lateral Raise", category: .shoulders,
                 primaryMuscles: ["三角肌中束"], muscleGroups: [.deltoids],
                 type: "侧平举", difficulty: 2,
                 maleVideo: "Cable Lateral Raise.mp4", femaleVideo: "Cable Lateral Raise.mp4"),
        Exercise("哑铃侧平举", "Dumbbell Lateral Raise", category: .shoulders,
                 primaryMuscles: ["三角肌中束"], muscleGroups: [.deltoids],
                 type: "侧平举", difficulty: 3,
                 maleVideo: "Dumbbell Lateral Raise.mp4", femaleVideo: "Dumbbell Lateral Raise.mp4"),
        Exercise("绳索肩推", "Cable Shoulder Press", category: .shoulders,
                 primaryMuscles: ["三角肌前束", "三角肌中束"], muscleGroups: [.frontDeltoids, .deltoids],
                 type: "肩上推举", difficulty: 2,
                 maleVideo: "Cable Shoulder Press.mp4", femaleVideo: "Cable Shoulder Press.mp4"),
        Exercise("哑铃阿诺德推举", "Dumbbell Arnold Press", category: .shoulders,
                 primaryMuscles: ["三角肌前束", "三角肌中束"], muscleGroups: [.frontDeltoids, .deltoids],
                 type: "肩上推举", difficulty: 3,
                 maleVideo: "Dumbbell Arnold Press.mp4", femaleVideo: "Dumbbell Arnold Press.mp4"),
        Exercise("哑铃坐姿肩推", "Dumbbell Seated Shoulder Press", category: .shoulders,
                 primaryMuscles: ["三角肌前束", "三角肌中束"], muscleGroups: [.frontDeltoids, .deltoids],
                 type: "肩上推举", difficulty: 2,
                 maleVideo: "Dumbbell Seated Shoulder Press.mp4", femaleVideo: "Dumbbell Seated Shoulder Press.mp4"),
        Exercise("壶铃斜向推举", "Kettlebell Angled Press", category: .shoulders,
                 primaryMuscles: ["三角肌前束", "三角肌中束"], muscleGroups: [.frontDeltoids, .deltoids],
                 type: "肩上推举", difficulty: 3,
                 maleVideo: "Kettlebell Angled Press.mp4", femaleVideo: "Kettlebell Angled Press.mp4"),
        Exercise("绳索直立划船", "Cable Upright Row", category: .shoulders,
                 primaryMuscles: ["三角肌中束", "斜方肌上束"], muscleGroups: [.deltoids, .trapezius],
                 type: "直立划船", difficulty: 3,
                 maleVideo: "Cable Upright Row.mp4", femaleVideo: "Cable Upright Row.mp4"),
        Exercise("杠铃耸肩", "Barbell Shrug", category: .shoulders,
                 primaryMuscles: ["斜方肌上束"], muscleGroups: [.trapezius],
                 type: "耸肩", difficulty: 3,
                 maleVideo: "Barbell-Shrug.mp4", femaleVideo: "Barbell-Shrug.mp4"),
        Exercise("俯卧 Y 字上举", "Prone Y Raise", category: .shoulders,
                 primaryMuscles: ["三角肌后束", "斜方肌中下束"], muscleGroups: [.rearDeltoids, .trapezius],
                 type: "反向飞鸟/上举", difficulty: 2,
                 maleVideo: "Prone Y Raise.mp4", femaleVideo: "Prone Y Raise.mp4"),
        Exercise("杠铃后三角划船", "Barbell Rear Delt Row", category: .shoulders,
                 primaryMuscles: ["三角肌后束", "斜方肌中下束"], muscleGroups: [.rearDeltoids, .trapezius],
                 type: "划船", difficulty: 3,
                 maleVideo: "Barbell-Rear-Delt-Row.mp4", femaleVideo: "Barbell-Rear-Delt-Row.mp4"),
        Exercise("阻力带外旋", "Resistance Band External Rotation", category: .shoulders,
                 primaryMuscles: ["肩袖肌群"], muscleGroups: [.deltoids],
                 type: "肩外旋/内收", difficulty: 2,
                 maleVideo: "Resistance Band External Rotation.mp4", femaleVideo: "Resistance Band External Rotation.mp4"),
        // MARK: arms (9)
        Exercise("杠铃弯举", "Barbell Curl", category: .arms,
                 primaryMuscles: ["肱二头肌"], muscleGroups: [.biceps],
                 type: "二头弯举", difficulty: 3,
                 maleVideo: "Barbell-Curl.mp4", femaleVideo: "Barbell-Curl.mp4"),
        Exercise("绳索锤式弯举", "Cable Hammer Curl", category: .arms,
                 primaryMuscles: ["肱二头肌"], muscleGroups: [.biceps],
                 type: "二头弯举", difficulty: 2,
                 maleVideo: "Cable Hammer Curl.mp4", femaleVideo: "Cable Hammer Curl.mp4"),
        Exercise("哑铃二头弯举", "Dumbbell Biceps Curl", category: .arms,
                 primaryMuscles: ["肱二头肌"], muscleGroups: [.biceps],
                 type: "二头弯举", difficulty: 3,
                 maleVideo: "Dumbbell-Biceps-Curl.mp4", femaleVideo: "Dumbbell-Biceps-Curl.mp4"),
        Exercise("哑铃坐姿锤式弯举", "Dumbbell Seated Hammer Curl", category: .arms,
                 primaryMuscles: ["肱二头肌"], muscleGroups: [.biceps],
                 type: "二头弯举", difficulty: 2,
                 maleVideo: "Dumbbell-Seated-Hammer-Curl.mp4", femaleVideo: "Dumbbell-Seated-Hammer-Curl.mp4"),
        Exercise("EZ 杠铃牧师凳弯举", "EZ Barbell Preacher Curl", category: .arms,
                 primaryMuscles: ["肱二头肌"], muscleGroups: [.biceps],
                 type: "二头弯举", difficulty: 3,
                 maleVideo: "Ez Barbell Preacher Curl.mp4", femaleVideo: "Ez Barbell Preacher Curl.mp4"),
        Exercise("壶铃二头弯举", "Kettlebell Biceps Curl", category: .arms,
                 primaryMuscles: ["肱二头肌"], muscleGroups: [.biceps],
                 type: "二头弯举", difficulty: 3,
                 maleVideo: "Kettlebell Biceps Curl.mp4", femaleVideo: "Kettlebell Biceps Curl.mp4"),
        Exercise("EZ 杠铃仰卧肱三头肌伸展", "EZ Barbell Lying Triceps Extension", category: .arms,
                 primaryMuscles: ["肱三头肌"], muscleGroups: [.triceps],
                 type: "三头下压/伸展", difficulty: 3,
                 maleVideo: "EZ Barbell Lying Triceps Extension.mp4", femaleVideo: "EZ Barbell Lying Triceps Extension.mp4"),
        Exercise("肱三头肌下压", "Triceps Press", category: .arms,
                 primaryMuscles: ["肱三头肌"], muscleGroups: [.triceps],
                 type: "三头下压/伸展", difficulty: 2,
                 maleVideo: "Triceps Press.mp4", femaleVideo: "Triceps Press.mp4"),
        Exercise("地面肱三头肌臂屈伸", "Triceps Dips Floor", category: .arms,
                 primaryMuscles: ["肱三头肌"], muscleGroups: [.triceps],
                 type: "臂屈伸(Dip)", difficulty: 3,
                 maleVideo: "Triceps-Dips-Floor.mp4", femaleVideo: "Triceps-Dips-Floor.mp4"),
        // MARK: lower (12)
        Exercise("徒手深蹲", "Air Squat", category: .lower,
                 primaryMuscles: ["股四头肌", "臀大肌"], muscleGroups: [.quadriceps, .gluteal],
                 type: "深蹲", difficulty: 3,
                 maleVideo: "Air-Squat.mp4", femaleVideo: "Air-Squat.mp4"),
        Exercise("杠铃深蹲", "Barbell Back Squat", category: .lower,
                 primaryMuscles: ["股四头肌", "臀大肌"], muscleGroups: [.quadriceps, .gluteal],
                 type: "深蹲", difficulty: 3,
                 maleVideo: "", femaleVideo: ""),
        Exercise("哑铃高脚杯深蹲", "Dumbbell Goblet Squat", category: .lower,
                 primaryMuscles: ["股四头肌", "臀大肌"], muscleGroups: [.quadriceps, .gluteal],
                 type: "深蹲", difficulty: 3,
                 maleVideo: "Dumbbell Goblet Squat.mp4", femaleVideo: "Dumbbell Goblet Squat.mp4"),
        Exercise("壶铃甲板深蹲", "Kettlebell Deck Squat", category: .lower,
                 primaryMuscles: ["股四头肌", "臀大肌"], muscleGroups: [.quadriceps, .gluteal],
                 type: "深蹲", difficulty: 3,
                 maleVideo: "Kettlebell Deck Squat.mp4", femaleVideo: "Kettlebell Deck Squat.mp4"),
        Exercise("杠铃罗马尼亚硬拉", "Barbell Romanian Deadlift", category: .lower,
                 primaryMuscles: ["臀大肌", "腘绳肌"], muscleGroups: [.gluteal, .hamstring],
                 type: "硬拉/髋铰链", difficulty: 3,
                 maleVideo: "", femaleVideo: ""),
        Exercise("杠铃直腿硬拉", "Barbell Straight Leg Deadlift", category: .lower,
                 primaryMuscles: ["臀大肌", "腘绳肌"], muscleGroups: [.gluteal, .hamstring],
                 type: "硬拉/髋铰链", difficulty: 3,
                 maleVideo: "Barbell-Straight-Leg-Deadlift.mp4", femaleVideo: "Barbell-Straight-Leg-Deadlift.mp4"),
        Exercise("哑铃罗马尼亚硬拉", "Dumbbell Romanian Deadlift", category: .lower,
                 primaryMuscles: ["臀大肌", "腘绳肌"], muscleGroups: [.gluteal, .hamstring],
                 type: "硬拉/髋铰链", difficulty: 3,
                 maleVideo: "Dumbbell Romanian Deadlift.mp4", femaleVideo: "Dumbbell Romanian Deadlift.mp4"),
        Exercise("臀桥", "Butt Bridge", category: .lower,
                 primaryMuscles: ["臀大肌"], muscleGroups: [.gluteal],
                 type: "臀桥/臀推", difficulty: 3,
                 maleVideo: "Butt-Bridge.mp4", femaleVideo: "Butt-Bridge.mp4"),
        Exercise("臀推", "Hip Thrusts", category: .lower,
                 primaryMuscles: ["臀大肌"], muscleGroups: [.gluteal],
                 type: "臀桥/臀推", difficulty: 3,
                 maleVideo: "Hip-Thrusts.mp4", femaleVideo: "Hip-Thrusts.mp4"),
        Exercise("哑铃弓步", "Dumbbell Lunge", category: .lower,
                 primaryMuscles: ["股四头肌", "臀大肌"], muscleGroups: [.quadriceps, .gluteal],
                 type: "弓步", difficulty: 3,
                 maleVideo: "Dumbbell Lunge.mp4", femaleVideo: "Dumbbell Lunge.mp4"),
        Exercise("前弓步", "Forward Lunge", category: .lower,
                 primaryMuscles: ["股四头肌", "臀大肌"], muscleGroups: [.quadriceps, .gluteal],
                 type: "弓步", difficulty: 3,
                 maleVideo: "Forward-Lunge.mp4", femaleVideo: "Forward-Lunge.mp4"),
        Exercise("腿屈伸", "Leg Extension", category: .lower,
                 primaryMuscles: ["股四头肌"], muscleGroups: [.quadriceps],
                 type: "腿屈伸", difficulty: 2,
                 maleVideo: "", femaleVideo: ""),
    ]
}
