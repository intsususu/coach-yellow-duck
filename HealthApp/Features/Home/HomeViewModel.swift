// HomeViewModel.swift
// 首页派生指标：体重 current/recentDelta 由最近 30 日序列计算；
// 睡眠、运动 hero 数取自 HomeMetricContract（数据契约常量）。

import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var weightHistory: [WeightSample] = []
    @Published private(set) var stats: WeightStats?
    /// 指标卡当日真实数（睡眠时长 / 锻炼分钟 / 活动热量及目标）。
    @Published private(set) var ringMetrics: HomeRingMetrics = .empty
    /// 睡眠卡：最近 30 日每日睡眠时长趋势。
    @Published private(set) var sleepTrend: [DailyMetric] = []
    /// 运动卡：最近 30 日每日活动热量趋势。
    @Published private(set) var energyTrend: [DailyMetric] = []
    /// 「本周小结」一句话：复用综合分析引擎，对最近 7 天与上一周对比生成。
    @Published private(set) var weeklyNarrative: String?

    func load(from repository: HealthDataRepository,
              events: [HealthEvent] = [],
              goalWeight: Double = 0) async {
        async let weeklyTask = repository.weightSeries(range: .week)
        async let ringsTask = repository.homeRingMetrics()
        async let sleepTask = repository.sleepDurationTrend()
        async let energyTask = repository.activeEnergyTrend()
        let history = await weeklyTask
        weightHistory = history
        stats = Self.makeStats(from: history)
        ringMetrics = await ringsTask
        sleepTrend = await sleepTask
        energyTrend = await energyTask
        weeklyNarrative = await Self.makeWeeklyNarrative(repository: repository,
                                                         events: events,
                                                         goalWeight: goalWeight)
    }

    /// 取最近一段（≥两周）的体重 / 睡眠 / 运动数据，以最新数据日为周末，
    /// 对「最近 7 天 vs 上一周」跑一遍综合分析引擎，仅取其合成的一句话小结。
    static func makeWeeklyNarrative(repository: HealthDataRepository,
                                    events: [HealthEvent],
                                    goalWeight: Double) async -> String? {
        async let weightsTask = repository.weightSeries(range: .month)
        async let sleepsTask = repository.sleepSeries(range: .month)
        async let workoutsTask = repository.workoutSessions()
        let (weights, sleeps, workouts) = await (weightsTask, sleepsTask, workoutsTask)

        let latest = [weights.map(\.date).max(),
                      sleeps.map(\.date).max(),
                      workouts.map(\.start).max()]
            .compactMap { $0 }
            .max()
        guard let latest else { return nil }

        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: latest)
        let startDate = calendar.date(byAdding: .day, value: -6, to: endDate) ?? endDate
        let report = AnalysisReportEngine().makeReport(weights: weights,
                                                       sleeps: sleeps,
                                                       workouts: workouts,
                                                       events: events,
                                                       goalWeight: goalWeight,
                                                       startDate: startDate,
                                                       endDate: endDate)
        return report.narrative
    }

    /// 首页三指标 hero 数的「最新一笔」：值 + 日期 + 是否当日测量。
    /// 当日有数据则显示「今日 X」，否则显示「最新 X」并附灰字日期。
    struct LatestMetric {
        let value: Double
        let date: Date?
        /// 最新一笔是否就是今天测得（无日期视为非当日）。
        var isToday: Bool {
            guard let date else { return false }
            return Calendar.current.isDateInToday(date)
        }
    }

    /// 最新体重（末点 kg 与测量日期）。
    var latestWeight: LatestMetric {
        LatestMetric(value: stats?.current ?? 0, date: weightHistory.last?.date)
    }
    /// 最新睡眠时长（末点小时数与测量日期）。
    var latestSleep: LatestMetric {
        LatestMetric(value: sleepTrend.last?.value ?? 0, date: sleepTrend.last?.date)
    }
    /// 最新活动热量（末点千卡与测量日期）。
    var latestEnergy: LatestMetric {
        LatestMetric(value: energyTrend.last?.value ?? 0, date: energyTrend.last?.date)
    }

    /// 最近 30 日睡眠时长日均（小时，保留 1 位）。
    var sleepAverage: Double? { Self.average(sleepTrend, places: 1) }
    /// 最近 30 日活动热量日均（千卡，取整）。
    var energyAverage: Double? { Self.average(energyTrend, places: 0) }

    static func average(_ points: [DailyMetric], places: Int) -> Double? {
        guard !points.isEmpty else { return nil }
        let mean = points.reduce(0) { $0 + $1.value } / Double(points.count)
        return mean.rounded(toPlaces: places)
    }

    /// 体重统计：当前 = 末点；最近 30 日变化 = 末点 − 30 日窗口首点。
    static func makeStats(from history: [WeightSample]) -> WeightStats? {
        guard let last = history.last else { return nil }
        let current = last.kg.rounded(toPlaces: 1)
        let window = recent30Days(from: history)
        let recentDelta = window.first.map { (last.kg - $0.kg).rounded(toPlaces: 1) } ?? 0
        return WeightStats(current: current,
                           recentDelta: recentDelta,
                           cumulativeChange: HomeMetricContract.cumulativeWeightChange)
    }

    /// Hero 卡折线只展示最近 30 日测量。
    var sparkline: [WeightSample] { Self.recent30Days(from: weightHistory) }

    /// 以最新样本为截止日，保留其前 29 日到截止日的测量。
    static func recent30Days(from series: [WeightSample], calendar: Calendar = .current) -> [WeightSample] {
        guard let latestDate = series.last?.date,
              let startDate = calendar.date(byAdding: .day, value: -29, to: latestDate) else {
            return series
        }
        return series.filter { $0.date >= startDate && $0.date <= latestDate }
    }
}
