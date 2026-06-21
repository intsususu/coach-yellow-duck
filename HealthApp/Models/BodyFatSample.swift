// BodyFatSample.swift
// 体脂样本（单点）：体脂肪质量（kg）与体脂率（%）。体脂趋势图双 Y 轴用。

import Foundation

struct BodyFatSample: Identifiable, Equatable, Codable {
    let id = UUID()
    let date: Date
    /// 体脂肪质量（kg）= 体重 × 体脂率。
    let fatMassKg: Double
    /// 体脂率（百分数，如 22.4 表示 22.4%）。
    let fatPercent: Double

    // 快照持久化：id 仅供 SwiftUI Identifiable，无需编码，解码时自动重生。
    private enum CodingKeys: String, CodingKey { case date, fatMassKg, fatPercent }
}
