// ExerciseSample.swift
// 运动样本（按月聚合或按次）。PRD §6.1。

import SwiftUI

struct ExerciseSample: Identifiable, Equatable {
    let id = UUID()
    let month: Date      // 该月起始日：月度图按月在横轴定位、支持跨年横滑
    let label: String    // 月份/日期标签，如 "1月"
    let kcal: Double      // 消耗千卡
    var avgHR: Double?    // 平均心率
    var minutes: Int?     // 时长
}

/// 单次运动记录（按次）。供运动统计卡计算运动天数 / 次数 / 时长 / 类型占比 / 时间段。
/// 与按日活动消耗（DailyMetric）不同：这里只含「主动开始的一次锻炼」，无锻炼的日不会出现。
struct WorkoutSession: Identifiable, Equatable {
    let id = UUID()
    let start: Date     // 运动开始时间（含时分，用于划分时间段）
    let type: WorkoutKind
    let minutes: Int    // 时长（分钟）
    let kcal: Double    // 本次活动消耗（千卡）
    var avgHR: Double?  // 本次平均心率（次/分），无记录时为 nil
}

/// 运动类型。占比卡按类型聚合计数。
enum WorkoutKind: String, CaseIterable, Identifiable {
    case running
    case strength
    case cycling
    case swimming
    case walking
    case yoga

    var id: String { rawValue }

    var label: String {
        switch self {
        case .running:  return "跑步"
        case .strength: return "力量"
        case .cycling:  return "骑行"
        case .swimming: return "游泳"
        case .walking:  return "步行"
        case .yoga:     return "瑜伽"
        }
    }

    var sfSymbol: String {
        switch self {
        case .running:  return "figure.run"
        case .strength: return "dumbbell.fill"
        case .cycling:  return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .walking:  return "figure.walk"
        case .yoga:     return "figure.yoga"
        }
    }

    var color: Color {
        switch self {
        case .running:  return .workoutRunning
        case .strength: return .workoutStrength
        case .cycling:  return .workoutCycling
        case .swimming: return .workoutSwimming
        case .walking:  return .workoutWalking
        case .yoga:     return .workoutYoga
        }
    }
}

/// 一天内的运动时间段：早上 / 中午 / 下午 / 晚上。按运动开始的小时划分。
enum WorkoutTimeBand: String, CaseIterable, Identifiable {
    case morning
    case noon
    case afternoon
    case evening

    var id: String { rawValue }

    var label: String {
        switch self {
        case .morning:   return "早上"
        case .noon:      return "中午"
        case .afternoon: return "下午"
        case .evening:   return "晚上"
        }
    }

    /// 早上 5–11 点、中午 11–14 点、下午 14–18 点，其余归晚上。
    init(hour: Int) {
        switch hour {
        case 5..<11:  self = .morning
        case 11..<14: self = .noon
        case 14..<18: self = .afternoon
        default:      self = .evening
        }
    }
}
