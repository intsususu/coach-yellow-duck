// Summaries.swift
// 派生指标聚合类型（混合策略：能由 mock 数组干净推导的字段计算得出；
// 个别与原型像素级对齐、但无法由 §6.2 数组干净推导的值，作为数据契约常量集中在此，
// 见 HomeMetricContract）。

import Foundation

/// 体重派生统计。`current` / `recentDelta` 由周序列计算；`cumulativeChange` 为契约常量。
struct WeightStats: Equatable {
    let current: Double          // 计算：周序列末点（四舍五入 1 位）
    let recentDelta: Double      // 计算：最近 30 次 末点 − 窗口首点
    let cumulativeChange: Double // 契约常量（原型「较起点」展示值）

    /// 距目标 = 当前 − 目标（保留 1 位）。目标可由「我的」编辑，故按需传入。
    func distance(to goalWeight: Double) -> Double {
        (current - goalWeight).rounded(toPlaces: 1)
    }
}

/// 首页三圆环的「当日真实指标」：睡眠时长 / 锻炼分钟 / 活动热量，及各自目标。
/// 锻炼与热量的「值 + 目标」均取自「健身」App 的活动环（HKActivitySummary）；
/// 睡眠时长取当日 sleepAnalysis 聚合，睡眠目标 HealthKit 不提供，用常量。
struct HomeRingMetrics: Equatable {
    var sleepHours: Double           // 当日睡眠总时长（小时）
    var sleepGoalHours: Double       // 睡眠目标（HealthKit 无此项，取常量）
    var exerciseMinutes: Int         // 健身环·锻炼分钟（appleExerciseTime）
    var exerciseGoalMinutes: Int     // 健身环·锻炼目标（appleExerciseTimeGoal）
    var activeKcal: Int              // 健身环·活动热量（activeEnergyBurned）
    var activeKcalGoal: Int          // 健身环·活动目标（activeEnergyBurnedGoal）

    /// 加载前 / 无数据时的占位（目标取 Apple 常见默认，避免除零）。
    static let empty = HomeRingMetrics(sleepHours: 0, sleepGoalHours: 8,
                                       exerciseMinutes: 0, exerciseGoalMinutes: 30,
                                       activeKcal: 0, activeKcalGoal: 500)
}

/// 首页圆环指标的原型数据契约值。
/// 这些是高保真原型「今日/本周」hero 展示数，无法由 §6.2 的月聚合 / 14 晚数组
/// 用单一公式干净反推，故按混合策略作为命名常量保留，保证与原型一致。
enum HomeMetricContract {
    /// 体重「较起点」累计变化（原型展示 −13.9；latest 77.1 与 start 91.2 的展示口径）。
    static let cumulativeWeightChange: Double = -13.9
    /// 日均睡眠时长（小时）。
    static let avgSleepHours: Double = 7.3
    /// 日均运动时长（分钟）。
    static let dailyExerciseMinutes: Int = 68
    /// 日均运动消耗（千卡）。
    static let dailyExerciseKcal: Int = 434
    /// 历史最高（起点）体重，留给 T04 体重页的统计三元组。
    static let startWeight: Double = 91.2
}
