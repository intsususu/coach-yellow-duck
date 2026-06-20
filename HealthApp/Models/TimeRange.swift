// TimeRange.swift
// 各页时间范围切换（睡眠/运动按需取子集）。PRD §8.2。

import Foundation

enum TimeRange: String, CaseIterable, Identifiable {
    case week
    case month
    case year
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .week:  return "周"
        case .month: return "月"
        case .year:  return "年"
        case .all:   return "全部"
        }
    }

    /// 趋势图可视窗口宽度（天）。仿 Apple 健康：周=7 天、月≈30 天、年≈12 月。
    /// `nil` 表示不分页，一次展示全部数据（「全部」）。
    var visibleDomainDays: Int? {
        switch self {
        case .week:  return 7
        case .month: return 30
        case .year:  return 365
        case .all:   return nil
        }
    }

    /// 可视窗口宽度（秒），用于 Charts 的 `chartXVisibleDomain(length:)`。
    var visibleDomainSeconds: TimeInterval? {
        visibleDomainDays.map { Double($0) * 86_400 }
    }
}

/// 供统一趋势卡的时间过滤按钮复用。
extension TimeRange: TrendRange {}
