// MockHealthRepository.swift
// 调试专用数据源：内置 PRD §6.2 全部 mock 数组（原样数值）。
// 整体以 #if DEBUG 包裹 —— 仅供 Claude/Codex 离线开发，绝不编入 Release（真机正式）二进制，
// 保证「正式使用时不出现 mock」。真机正式构建一律走 HealthKitRepository + EventRepository。

import Foundation

#if DEBUG
final class MockHealthRepository: HealthDataRepository {

    /// 事件本机持久化（首次启动落种子；saveEvent 走 upsert）。
    private let eventStore: EventStore

    init(eventStore: EventStore = EventStore()) {
        self.eventStore = eventStore
    }

    // MARK: - HealthDataRepository

    func requestAuthorization() async throws { }

    func homeRingMetrics() async -> HomeRingMetrics {
        // 「当日」睡眠取最近一晚；锻炼/热量及目标沿用原型契约值，保证 Mock 视觉一致。
        let todaySleepHours = Self.recentSleep.last.map { Double($0.totalMinutes) / 60.0 }
            ?? HomeMetricContract.avgSleepHours
        return HomeRingMetrics(sleepHours: todaySleepHours.rounded(toPlaces: 1),
                               sleepGoalHours: 8,
                               exerciseMinutes: HomeMetricContract.dailyExerciseMinutes,
                               exerciseGoalMinutes: 90,
                               activeKcal: HomeMetricContract.dailyExerciseKcal,
                               activeKcalGoal: 600)
    }

    func sleepDurationTrend() async -> [DailyMetric] {
        Self.dailySleepHours
    }

    func activeEnergyTrend() async -> [DailyMetric] {
        Self.dailyActiveKcal
    }

    func weightSeries(range: TimeRange) async -> [WeightSample] {
        switch range {
        // 周 / 月：日级序列，由可视窗口（7 天 / 30 天）滑动取景。
        case .week, .month: return Self.dailyWeights
        // 年：月级序列，按 12 个月的窗口滑动。
        case .year:         return Self.monthlyWeightsExtended
        case .all:          return Self.yearlyWeights
        }
    }

    func recentWeightRecords(limit: Int) async -> [WeightSample] {
        Array(Self.dailyWeights.suffix(limit).reversed())
    }

    func weightStatistics() async -> WeightStatistics {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let thisYear = Self.dailyWeights.filter { calendar.component(.year, from: $0.date) == currentYear }
        let allValues = Self.dailyWeights.map(\.kg)

        return WeightStatistics(
            current: Self.dailyWeights.last?.kg.rounded(toPlaces: 1),
            yearHigh: thisYear.map(\.kg).max()?.rounded(toPlaces: 1),
            yearLow: thisYear.map(\.kg).min()?.rounded(toPlaces: 1),
            // 历史极值并入高保真原型的完整边界（§6.2 图表仅含聚合子集）。
            allTimeHigh: max(allValues.max() ?? WeightHistoryContract.startWeight,
                             WeightHistoryContract.startWeight),
            allTimeLow: min(allValues.min() ?? WeightHistoryContract.historicalLow,
                            WeightHistoryContract.historicalLow)
        )
    }

    func sleepSeries(range: TimeRange) async -> [SleepSample] {
        // 统一返回近 6 个月日级序列；睡眠页按可视窗口（周 / 月）滑动取景，
        // 「6 个月」由视图层聚合成周平均。范围参数仅用于上层选择呈现方式。
        Self.extendedSleep
    }

    func exerciseSeries(range: TimeRange) async -> [ExerciseSample] {
        Self.recentExercise
    }

    func events() async -> [HealthEvent] {
        eventStore.load()
    }

    func saveEvent(_ event: HealthEvent) async {
        eventStore.upsert(event)
    }

    func deleteEvent(_ event: HealthEvent) async {
        eventStore.delete(event)
    }
}

// MARK: - Mock 数据集（原样取自 PRD §6.2 / 高保真原型）

private extension MockHealthRepository {

    /// 高保真原型的完整历史边界；§6.2 图表聚合仅含其子集。
    enum WeightHistoryContract {
        static let startWeight = 91.2     // 历史最高（起始体重）
        static let historicalLow = 71.9   // 历史最低
    }


    /// 体重 — 月（近 12 月）。
    static let monthlyWeights: [WeightSample] = [
        ("2025-07-15", 75.3), ("2025-08-15", 75.0), ("2025-09-15", 75.5), ("2025-10-15", 78.6),
        ("2025-11-15", 81.3), ("2025-12-15", 81.6), ("2026-01-15", 81.2), ("2026-02-15", 81.4),
        ("2026-03-15", 83.6), ("2026-04-15", 82.7), ("2026-05-15", 80.9), ("2026-06-15", 78.0),
    ].map { WeightSample(date: HealthEvent.date($0.0), kg: $0.1) }

    /// 体重 — 月级（含上一年），供「年」视图按 12 个月窗口左滑回溯。
    static let monthlyWeightsExtended: [WeightSample] = ([
        ("2024-07-15", 84.0), ("2024-08-15", 84.5), ("2024-09-15", 83.2), ("2024-10-15", 82.0),
        ("2024-11-15", 80.5), ("2024-12-15", 79.0), ("2025-01-15", 78.2), ("2025-02-15", 77.5),
        ("2025-03-15", 77.0), ("2025-04-15", 76.4), ("2025-05-15", 76.0), ("2025-06-15", 75.6),
    ].map { WeightSample(date: HealthEvent.date($0.0), kg: $0.1) }) + monthlyWeights

    /// 体重 — 日级序列（2025-07 ~ 2026-06）。由月级锚点线性插值并叠加确定性抖动，
    /// 供「周 / 月」视图以固定宽度窗口滑动取景（仿 Apple 健康）。
    static let dailyWeights: [WeightSample] = makeDailyWeights()

    private static func makeDailyWeights(calendar: Calendar = .current) -> [WeightSample] {
        // 锚点沿用月级真值，末尾补 2026-06-18 收口到周视图末点。
        let anchors: [(Date, Double)] = ([
            ("2025-07-15", 75.3), ("2025-08-15", 75.0), ("2025-09-15", 75.5), ("2025-10-15", 78.6),
            ("2025-11-15", 81.3), ("2025-12-15", 81.6), ("2026-01-15", 81.2), ("2026-02-15", 81.4),
            ("2026-03-15", 83.6), ("2026-04-15", 82.7), ("2026-05-15", 80.9), ("2026-06-15", 78.0),
            ("2026-06-18", 77.1),
        ]).map { (HealthEvent.date($0.0), $0.1) }

        var result: [WeightSample] = []
        for i in 0..<(anchors.count - 1) {
            let (d0, v0) = anchors[i]
            let (d1, v1) = anchors[i + 1]
            let span = max(calendar.dateComponents([.day], from: d0, to: d1).day ?? 0, 1)
            for k in 0..<span {
                guard let date = calendar.date(byAdding: .day, value: k, to: d0) else { continue }
                let value = v0 + (v1 - v0) * Double(k) / Double(span)
                let jitter = 0.3 * sin(Double(result.count) * 0.7)
                result.append(WeightSample(date: date, kg: (value + jitter).rounded(toPlaces: 1)))
            }
        }
        if let last = anchors.last {
            result.append(WeightSample(date: last.0, kg: last.1))
        }
        return result
    }

    /// 体重 — 年（均值）。
    static let yearlyWeights: [WeightSample] = [
        ("2019-07-01", 77.2), ("2020-07-01", 76.0), ("2022-07-01", 84.9), ("2023-07-01", 82.8),
        ("2024-07-01", 84.2), ("2025-07-01", 79.4), ("2026-04-01", 81.1),
    ].map { WeightSample(date: HealthEvent.date($0.0), kg: $0.1) }

    /// 睡眠 — 近 14 晚（2026-06-04 ~ 06-17）。
    static let recentSleep: [SleepSample] = [
        SleepSample(date: HealthEvent.date("2026-06-04"), totalMinutes: 429, deepMinutes: 38, coreMinutes: 278, remMinutes: 95,  awakeMinutes: 18, efficiency: 0.96),
        SleepSample(date: HealthEvent.date("2026-06-05"), totalMinutes: 436, deepMinutes: 42, coreMinutes: 281, remMinutes: 98,  awakeMinutes: 15, efficiency: 0.97),
        SleepSample(date: HealthEvent.date("2026-06-06"), totalMinutes: 515, deepMinutes: 55, coreMinutes: 335, remMinutes: 110, awakeMinutes: 15, efficiency: 0.97),
        SleepSample(date: HealthEvent.date("2026-06-07"), totalMinutes: 464, deepMinutes: 22, coreMinutes: 310, remMinutes: 102, awakeMinutes: 30, efficiency: 0.88), // 饮酒夜
        SleepSample(date: HealthEvent.date("2026-06-08"), totalMinutes: 392, deepMinutes: 30, coreMinutes: 258, remMinutes: 85,  awakeMinutes: 19, efficiency: 0.95),
        SleepSample(date: HealthEvent.date("2026-06-09"), totalMinutes: 446, deepMinutes: 40, coreMinutes: 290, remMinutes: 99,  awakeMinutes: 17, efficiency: 0.96),
        SleepSample(date: HealthEvent.date("2026-06-10"), totalMinutes: 389, deepMinutes: 28, coreMinutes: 248, remMinutes: 88,  awakeMinutes: 25, efficiency: 0.90), // 出差起
        SleepSample(date: HealthEvent.date("2026-06-11"), totalMinutes: 497, deepMinutes: 45, coreMinutes: 324, remMinutes: 108, awakeMinutes: 20, efficiency: 0.96),
        SleepSample(date: HealthEvent.date("2026-06-12"), totalMinutes: 487, deepMinutes: 43, coreMinutes: 316, remMinutes: 105, awakeMinutes: 23, efficiency: 0.95),
        SleepSample(date: HealthEvent.date("2026-06-13"), totalMinutes: 398, deepMinutes: 26, coreMinutes: 252, remMinutes: 90,  awakeMinutes: 30, efficiency: 0.90),
        SleepSample(date: HealthEvent.date("2026-06-14"), totalMinutes: 438, deepMinutes: 35, coreMinutes: 282, remMinutes: 97,  awakeMinutes: 24, efficiency: 0.93),
        SleepSample(date: HealthEvent.date("2026-06-15"), totalMinutes: 389, deepMinutes: 33, coreMinutes: 252, remMinutes: 86,  awakeMinutes: 18, efficiency: 0.95), // 出差止
        SleepSample(date: HealthEvent.date("2026-06-16"), totalMinutes: 446, deepMinutes: 41, coreMinutes: 290, remMinutes: 98,  awakeMinutes: 17, efficiency: 0.96),
        SleepSample(date: HealthEvent.date("2026-06-17"), totalMinutes: 335, deepMinutes: 28, coreMinutes: 218, remMinutes: 71,  awakeMinutes: 18, efficiency: 0.94),
    ]

    /// 睡眠 — 近 6 个月日级序列（含阶段分解）。前段为确定性生成、末段并入 `recentSleep` 真值，
    /// 供睡眠页「周 / 月」堆积图滑动取景，并由视图层聚合为「6 个月」周平均趋势。
    static let extendedSleep: [SleepSample] = makeEarlySleep() + recentSleep

    /// 生成 `recentSleep` 之前约 5 个月的每日睡眠（截至 2026-06-03），各阶段按经验占比拆分。
    private static func makeEarlySleep(calendar: Calendar = .current) -> [SleepSample] {
        let end = HealthEvent.date("2026-06-03")
        let dayCount = 168
        var result: [SleepSample] = []
        for i in 0..<dayCount {
            guard let date = calendar.date(byAdding: .day, value: -(dayCount - i), to: end) else { continue }
            let phase = Double(i)
            // 时间在床（含清醒）≈ 6.3–8.2h，叠加确定性周期波动与周末略长。
            let weekday = calendar.component(.weekday, from: date)
            let weekendBonus = (weekday == 1 || weekday == 7) ? 24.0 : 0
            let total = 430.0 + 36.0 * sin(phase * 0.5) + 17.0 * sin(phase * 0.17) + weekendBonus
            let totalMin = Int(total.rounded())
            let awake = Int((Double(totalMin) * (0.045 + 0.018 * abs(sin(phase * 0.31)))).rounded())
            let deep = Int((Double(totalMin) * (0.095 + 0.018 * sin(phase * 0.23))).rounded())
            let rem = Int((Double(totalMin) * (0.215 + 0.015 * sin(phase * 0.41))).rounded())
            let core = max(totalMin - deep - rem - awake, 60)
            let efficiency = (Double(deep + core + rem) / Double(totalMin) * 100).rounded() / 100
            result.append(SleepSample(date: date, totalMinutes: deep + core + rem + awake,
                                      deepMinutes: deep, coreMinutes: core, remMinutes: rem,
                                      awakeMinutes: awake, efficiency: efficiency))
        }
        return result
    }

    /// 首页睡眠卡 — 最近 30 日每日睡眠时长（小时）。末点 5.6h 对齐 recentSleep 最后一晚。
    static let dailySleepHours: [DailyMetric] = makeDailyTrend(
        endingOn: "2026-06-17",
        values: [7.2, 7.5, 6.8, 7.0, 7.8, 8.1, 7.4, 6.9, 7.1, 7.6,
                 6.5, 7.3, 7.9, 8.0, 7.2, 6.7, 7.0, 7.5, 7.8, 7.1,
                 6.8, 7.4, 7.6, 8.2, 7.0, 6.9, 7.3, 7.7, 7.4, 5.6])

    /// 首页运动卡 — 最近 30 日每日活动热量（千卡）。末点 434 对齐契约 dailyExerciseKcal。
    static let dailyActiveKcal: [DailyMetric] = makeDailyTrend(
        endingOn: "2026-06-17",
        values: [410, 380, 520, 470, 350, 290, 430, 510, 460, 400,
                 330, 480, 540, 390, 420, 360, 500, 470, 310, 440,
                 520, 380, 410, 560, 470, 350, 430, 490, 450, 434])

    /// 把一组连续每日数值映射成以 `endingOn` 为末日、向前回溯的 DailyMetric 序列。
    static func makeDailyTrend(endingOn dateString: String, values: [Double],
                               calendar: Calendar = .current) -> [DailyMetric] {
        let endDate = HealthEvent.date(dateString)
        return values.enumerated().compactMap { index, value in
            guard let date = calendar.date(byAdding: .day,
                                           value: -(values.count - 1 - index),
                                           to: endDate) else { return nil }
            return DailyMetric(date: date, value: value)
        }
    }

    /// 运动 — 近 6 个月（千卡 / 平均心率）。
    static let recentExercise: [ExerciseSample] = [
        ExerciseSample(label: "1月", kcal: 6822,  avgHR: 135.3),
        ExerciseSample(label: "2月", kcal: 822,   avgHR: 150.3), // 生病，偏低
        ExerciseSample(label: "3月", kcal: 4899,  avgHR: 130.4),
        ExerciseSample(label: "4月", kcal: 8362,  avgHR: 122.6),
        ExerciseSample(label: "5月", kcal: 14841, avgHR: 115.9), // 月末拉伤
        ExerciseSample(label: "6月", kcal: 3714,  avgHR: 109.9), // 不完整月
    ]
}
#endif
