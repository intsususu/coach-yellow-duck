// WeightStatistics.swift
// 体重统计卡聚合：当前 / 今年极值 / 历史极值 / 累计减少（下坡段累加）。

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
    /// 「下坡段」：每段为一个体重高峰回落到随后低谷的减少，按时间先后排列。
    /// 仅统计下坡，回升期不计入；累计减少 = 各段减少之和。
    var lossSegments: [WeightLossSegment] = []

    /// 累计减少 = 所有「下坡段」减少量之和（恒为非负）。
    /// 无任何测量时返回 nil（如真机授权前），有数据但无显著下坡时为 0。
    var cumulativeLoss: Double? {
        guard current != nil else { return nil }
        return lossSegments.reduce(0) { $0 + max($1.peakKg - $1.valleyKg, 0) }.rounded(toPlaces: 1)
    }
}

/// 一段下坡：从高峰（startDate / peakKg）回落到随后的低谷（endDate / valleyKg）。
struct WeightLossSegment: Identifiable, Equatable, Codable {
    let id = UUID()
    /// 高峰日期。
    let startDate: Date
    /// 低谷日期。
    let endDate: Date
    /// 高峰体重（kg）。
    let peakKg: Double
    /// 低谷体重（kg）。
    let valleyKg: Double

    /// 本段减少（kg，恒为非负）。
    var drop: Double { max(peakKg - valleyKg, 0).rounded(toPlaces: 1) }

    // 快照持久化：id 仅供 SwiftUI Identifiable，无需编码，解码时自动重生。
    private enum CodingKeys: String, CodingKey { case startDate, endDate, peakKg, valleyKg }
}

extension WeightLossSegment {
    /// 从体重序列中提取「下坡段」：从首次测量起，找到每个显著高峰，累加其回落到随后低谷的减少。
    ///
    /// 采用 ZigZag 反转过滤识别峰 / 谷：只有当反向位移超过 `threshold`（kg）时才确认一次转折，
    /// 借此过滤日常体重波动 / 称重误差的噪声，只保留「真正的」大段下坡。
    /// - Parameters:
    ///   - samples: 体重样本（无需预排序）。
    ///   - threshold: 确认转折所需的最小反弹幅度（kg），默认 3.0。
    static func segments(from samples: [WeightSample], threshold: Double = 3.0) -> [WeightLossSegment] {
        let series = samples.sorted { $0.date < $1.date }
        guard series.count >= 2 else { return [] }

        // 交替排列的已确认转折点（峰、谷、峰…）。
        var pivots: [WeightSample] = []
        // 1 = 上行，-1 = 下行，0 = 方向未定。
        var trend = 0
        // 未定向时分别跟踪运行最高 / 最低；定向后 extreme 跟踪当前方向上的极值（候选转折点）。
        var runMax = series[0]
        var runMin = series[0]
        var extreme = series[0]

        for sample in series.dropFirst() {
            switch trend {
            case 1: // 上行：extreme 为候选高峰
                if sample.kg >= extreme.kg {
                    extreme = sample
                } else if extreme.kg - sample.kg >= threshold {
                    pivots.append(extreme)   // 确认高峰
                    trend = -1
                    extreme = sample
                }
            case -1: // 下行：extreme 为候选低谷
                if sample.kg <= extreme.kg {
                    extreme = sample
                } else if sample.kg - extreme.kg >= threshold {
                    pivots.append(extreme)   // 确认低谷
                    trend = 1
                    extreme = sample
                }
            default: // 方向未定：等首个超过阈值的位移定向
                if sample.kg > runMax.kg { runMax = sample }
                if sample.kg < runMin.kg { runMin = sample }
                if runMax.kg - sample.kg >= threshold {
                    pivots.append(runMax)    // 起始为高峰，随后下行
                    trend = -1
                    extreme = sample
                } else if sample.kg - runMin.kg >= threshold {
                    pivots.append(runMin)    // 起始为低谷，随后上行
                    trend = 1
                    extreme = sample
                }
            }
        }
        // 收尾：把进行中的摆动末点纳入，完成最后一段下坡 / 上坡。
        pivots.append(extreme)

        // 相邻 pivot 中「峰 → 谷」（前高后低）即为一段下坡。
        var segments: [WeightLossSegment] = []
        for index in 1..<pivots.count {
            let peak = pivots[index - 1]
            let valley = pivots[index]
            guard peak.kg > valley.kg else { continue }
            segments.append(WeightLossSegment(startDate: peak.date,
                                              endDate: valley.date,
                                              peakKg: peak.kg.rounded(toPlaces: 1),
                                              valleyKg: valley.kg.rounded(toPlaces: 1)))
        }
        return segments
    }
}
