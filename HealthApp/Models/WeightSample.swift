// WeightSample.swift
// 体重样本（单点）。PRD §6.1。

import Foundation

struct WeightSample: Identifiable, Equatable, Codable {
    let id = UUID()
    let date: Date
    let kg: Double

    // 快照持久化：id 仅供 SwiftUI Identifiable，无需编码，解码时自动重生。
    private enum CodingKeys: String, CodingKey { case date, kg }
}
