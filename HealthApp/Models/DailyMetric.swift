// DailyMetric.swift
// 通用「按日趋势」点：首页睡眠/运动卡的最近 30 日折线复用此类型。

import Foundation

struct DailyMetric: Identifiable, Equatable, Codable {
    let id = UUID()
    let date: Date
    let value: Double

    // 快照持久化：id 仅供 SwiftUI Identifiable，无需编码，解码时自动重生。
    private enum CodingKeys: String, CodingKey { case date, value }
}
