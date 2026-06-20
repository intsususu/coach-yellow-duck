// HealthEvent.swift
// 事件类型与特殊事件模型。PRD §6.1，色板见 §4.2（统一走 Color+Tokens）。

import Foundation
import SwiftUI

/// 统一的 4 类特殊事件（PRD §4.2）：伤病（红）、出行（蓝）、饮酒（紫）、其他（灰）。
/// 「出行」覆盖旅行与出差；「伤病」覆盖生病与损伤。
enum EventType: String, CaseIterable, Codable {
    case illness   // 伤病
    case travel    // 出行
    case drink     // 饮酒
    case other     // 其他

    var label: String {
        switch self {
        case .illness: return "伤病"
        case .travel:  return "出行"
        case .drink:   return "饮酒"
        case .other:   return "其他"
        }
    }

    /// 事件主色（PRD §4.2）。
    var color: Color {
        switch self {
        case .illness: return .eventIllness
        case .travel:  return .eventTravel
        case .drink:   return .eventDrink
        case .other:   return .eventOther
        }
    }

    /// 事件背景色（PRD §4.2）。
    var backgroundColor: Color {
        switch self {
        case .illness: return .eventIllnessBg
        case .travel:  return .eventTravelBg
        case .drink:   return .eventDrinkBg
        case .other:   return .eventOtherBg
        }
    }

    var sfSymbol: String {
        switch self {
        case .illness: return "cross.case.fill"
        case .travel:  return "airplane"
        case .drink:   return "wineglass"
        case .other:   return "star.circle"
        }
    }

    /// 是否会直接关联睡眠趋势。`travel` 同时覆盖旅行与出差场景。
    var isSleepRelated: Bool {
        self == .drink || self == .travel
    }

    /// 是否会直接关联运动趋势：伤病停训、出行打乱训练计划。
    var isExerciseRelated: Bool {
        self == .illness || self == .travel
    }

    // MARK: - Codable（含旧数据迁移）

    /// 兼容历史本机数据：旧版「出差」曾被错误存为 `injury`，现统一并入「出行」(travel)；
    /// 其余未知原始值回落到「其他」(other)，保证旧事件不会因分类调整而解码失败。
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "injury": self = .travel
        default:       self = EventType(rawValue: raw) ?? .other
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// 特殊事件：单日（endDate == nil）或时间段（endDate != nil）。
struct HealthEvent: Identifiable, Codable, Equatable {
    let id: String
    var type: EventType
    var title: String
    var startDate: Date
    var endDate: Date?
    var note: String

    var isPeriod: Bool { endDate != nil }

    // MARK: - 日期解析（"yyyy-MM-dd"）

    static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    static func date(_ s: String) -> Date {
        isoFormatter.date(from: s) ?? Date()
    }
}
