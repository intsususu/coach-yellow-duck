// WeightStatistics.swift
// 体重统计卡聚合：当前 / 今年极值 / 历史极值 / 累计减少。

import Foundation

struct WeightStatistics: Equatable, Codable {
    /// 最新一次测量。
    var current: Double?
    /// 今年最高 / 最低。
    var yearHigh: Double?
    var yearLow: Double?
    /// 历史最高 / 最低（全部记录）。
    var allTimeHigh: Double?
    var allTimeLow: Double?

    /// 累计减少 = 历史最高 − 当前（恒为非负）。
    var cumulativeLoss: Double? {
        guard let current, let allTimeHigh else { return nil }
        return max(allTimeHigh - current, 0).rounded(toPlaces: 1)
    }
}
