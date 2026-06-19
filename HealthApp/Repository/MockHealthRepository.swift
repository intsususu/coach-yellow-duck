// MockHealthRepository.swift
// 阶段一数据源：内置 PRD §6.2 全部 mock 数组（原样数值）。
// 阶段二将由 HealthKitRepository 实现同一协议替换之。

import Foundation

final class MockHealthRepository: HealthDataRepository {

    /// 事件内存存储（初始 4 条，saveEvent 追加到顶部）。
    private var eventStore: [HealthEvent] = MockHealthRepository.initialEvents

    // MARK: - HealthDataRepository

    func requestAuthorization() async throws { }

    func weightSeries(range: TimeRange) async -> [WeightSample] {
        switch range {
        case .week:  return Self.weeklyWeights
        case .month: return Self.monthlyWeights
        case .year:  return Self.yearlyWeights
        case .all:   return Self.yearlyWeights
        }
    }

    func sleepSeries(range: TimeRange) async -> [SleepSample] {
        switch range {
        case .week: return Array(Self.recentSleep.suffix(7))
        default:    return Self.recentSleep
        }
    }

    func exerciseSeries(range: TimeRange) async -> [ExerciseSample] {
        Self.recentExercise
    }

    func events() async -> [HealthEvent] {
        eventStore
    }

    func saveEvent(_ event: HealthEvent) async {
        eventStore.insert(event, at: 0)
    }
}

// MARK: - Mock 数据集（原样取自 PRD §6.2 / 高保真原型）

private extension MockHealthRepository {

    /// 体重 — 周（2026 上半年，16 点）。
    static let weeklyWeights: [WeightSample] = [
        ("2026-01-05", 80.87), ("2026-01-12", 81.10), ("2026-01-26", 81.60), ("2026-02-02", 81.40),
        ("2026-03-23", 83.83), ("2026-03-30", 83.40), ("2026-04-06", 82.80), ("2026-04-13", 82.60),
        ("2026-04-20", 82.58), ("2026-05-04", 81.85), ("2026-05-11", 81.62), ("2026-05-18", 80.58),
        ("2026-05-25", 79.56), ("2026-06-01", 78.90), ("2026-06-08", 78.00), ("2026-06-15", 77.07),
    ].map { WeightSample(date: HealthEvent.date($0.0), kg: $0.1) }

    /// 体重 — 月（近 12 月）。
    static let monthlyWeights: [WeightSample] = [
        ("2025-07-15", 75.3), ("2025-08-15", 75.0), ("2025-09-15", 75.5), ("2025-10-15", 78.6),
        ("2025-11-15", 81.3), ("2025-12-15", 81.6), ("2026-01-15", 81.2), ("2026-02-15", 81.4),
        ("2026-03-15", 83.6), ("2026-04-15", 82.7), ("2026-05-15", 80.9), ("2026-06-15", 78.0),
    ].map { WeightSample(date: HealthEvent.date($0.0), kg: $0.1) }

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

    /// 运动 — 近 6 个月（千卡 / 平均心率）。
    static let recentExercise: [ExerciseSample] = [
        ExerciseSample(label: "1月", kcal: 6822,  avgHR: 135.3),
        ExerciseSample(label: "2月", kcal: 822,   avgHR: 150.3), // 生病，偏低
        ExerciseSample(label: "3月", kcal: 4899,  avgHR: 130.4),
        ExerciseSample(label: "4月", kcal: 8362,  avgHR: 122.6),
        ExerciseSample(label: "5月", kcal: 14841, avgHR: 115.9), // 月末拉伤
        ExerciseSample(label: "6月", kcal: 3714,  avgHR: 109.9), // 不完整月
    ]

    /// 初始 4 条事件。
    static let initialEvents: [HealthEvent] = [
        HealthEvent(id: "e1", type: .travel,  title: "出差 · 上海",
                    startDate: HealthEvent.date("2026-06-10"), endDate: HealthEvent.date("2026-06-14"),
                    note: "作息紊乱，运动暂停"),
        HealthEvent(id: "e2", type: .drink,   title: "饮酒 · 聚餐",
                    startDate: HealthEvent.date("2026-06-07"), endDate: nil,
                    note: "深睡下降，效率降到 88%"),
        HealthEvent(id: "e3", type: .illness, title: "感冒发烧",
                    startDate: HealthEvent.date("2026-05-31"), endDate: nil,
                    note: "已就医，停训一周，体重回升 0.6kg"),
        HealthEvent(id: "e4", type: .injury,  title: "腰肌肉拉伤",
                    startDate: HealthEvent.date("2026-05-20"), endDate: HealthEvent.date("2026-05-27"),
                    note: "停训一周，周消耗降到平时 1/3"),
    ]
}
