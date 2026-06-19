// HomeViewModel.swift
// 首页派生指标（混合策略）：体重 current/recentDelta 由周序列计算；
// 累计、睡眠、运动 hero 数取自 HomeMetricContract（数据契约常量）。

import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var weeklyWeights: [WeightSample] = []
    @Published private(set) var stats: WeightStats?
    /// 三圆环当日真实指标（睡眠时长 / 锻炼分钟 / 活动热量及目标）。
    @Published private(set) var ringMetrics: HomeRingMetrics = .empty

    func load(from repository: HealthDataRepository) async {
        async let weeklyTask = repository.weightSeries(range: .week)
        async let ringsTask = repository.homeRingMetrics()
        let weekly = await weeklyTask
        weeklyWeights = weekly
        stats = Self.makeStats(from: weekly)
        ringMetrics = await ringsTask
    }

    /// 体重统计：当前 = 末点；最近30次 = 末点 − 窗口首点；累计 = 契约常量。
    static func makeStats(from weekly: [WeightSample]) -> WeightStats? {
        guard let last = weekly.last else { return nil }
        let current = last.kg.rounded(toPlaces: 1)
        let window = recent30(from: weekly)
        let recentDelta = window.first.map { (last.kg - $0.kg).rounded(toPlaces: 1) } ?? 0
        return WeightStats(current: current,
                           recentDelta: recentDelta,
                           cumulativeChange: HomeMetricContract.cumulativeWeightChange)
    }

    /// Hero 卡折线 sparkline 取最近 30 次测量。
    var sparkline: [WeightSample] { Self.recent30(from: weeklyWeights) }

    /// 最近 30 次测量（不足 30 次则取全部）。
    static func recent30(from series: [WeightSample]) -> [WeightSample] {
        Array(series.suffix(30))
    }
}
