// DataModels.swift
// 健康数据分析 · Mock Data
// Drop this file into your Xcode project. All structs are ready to use.
// Replace mock data with real HealthKit queries in Phase 2.

import Foundation
import SwiftUI

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:(a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255)
    }
}

// MARK: - Design Tokens

struct AppColors {
    // Primary
    static let primary       = Color(hex: "#2F6BFF")
    static let primaryDark   = Color(hex: "#1F4FD6")

    // Backgrounds
    static let appBG         = Color(hex: "#F5F6F8")
    static let cardBG        = Color.white
    static let subtleBG      = Color(hex: "#ECF0F3")

    // Text
    static let textPrimary   = Color(hex: "#1F2733")
    static let textSecondary = Color(hex: "#9AA6B4")
    static let textBody      = Color(hex: "#5B6675")

    // Data
    static let weight        = Color(hex: "#2F6BFF")
    static let sleep         = Color(hex: "#6366F1")
    static let sleepDark     = Color(hex: "#4338CA")
    static let sleepLight    = Color(hex: "#A5B4FC")
    static let exercise      = Color(hex: "#16A34A")
    static let goalLine      = Color(hex: "#EA580C")

    // Events
    static let illness       = Color(hex: "#EF4444")
    static let injury        = Color(hex: "#EA580C")
    static let drink         = Color(hex: "#7C3AED")
    static let travel        = Color(hex: "#0891B2")
    static let other         = Color(hex: "#64748B")

    // Semantic
    static let success       = Color(hex: "#16A34A")
    static let warning       = Color(hex: "#EA580C")
    static let danger        = Color(hex: "#EF4444")
}

// MARK: - Event Model

enum EventType: String, CaseIterable, Codable {
    case illness = "illness"
    case injury  = "injury"
    case drink   = "drink"
    case travel  = "travel"
    case other   = "other"

    var label: String {
        switch self {
        case .illness: return "生病"
        case .injury:  return "损伤"
        case .drink:   return "饮酒"
        case .travel:  return "旅行"
        case .other:   return "其他"
        }
    }

    var color: Color {
        switch self {
        case .illness: return AppColors.illness
        case .injury:  return AppColors.injury
        case .drink:   return AppColors.drink
        case .travel:  return AppColors.travel
        case .other:   return AppColors.other
        }
    }

    var backgroundColor: Color {
        switch self {
        case .illness: return Color(hex: "#FDECEC")
        case .injury:  return Color(hex: "#FDF1EA")
        case .drink:   return Color(hex: "#F3EEFC")
        case .travel:  return Color(hex: "#E7F5F8")
        case .other:   return Color(hex: "#F1F3F5")
        }
    }

    var sfSymbol: String {
        switch self {
        case .illness: return "cross.circle"
        case .injury:  return "bandage"
        case .drink:   return "wineglass"
        case .travel:  return "airplane"
        case .other:   return "star.circle"
        }
    }
}

struct HealthEvent: Identifiable, Codable {
    var id: String
    var type: EventType
    var title: String
    var date: Date
    var endDate: Date?        // optional — for multi-day events like travel
    var note: String

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    static func date(_ s: String) -> Date {
        dateFormatter.date(from: s) ?? Date()
    }
}

// MARK: - Weight Model

struct WeightEntry: Identifiable {
    var id: String { date }
    var date: String   // "yyyy-MM-dd"
    var kg: Double

    var parsedDate: Date { HealthEvent.date(date) }
}

// MARK: - Sleep Model

struct SleepEntry: Identifiable {
    var id: String { date }
    var date: String        // "yyyy-MM-dd"
    var totalMinutes: Int
    var deepMinutes: Int
    var coreMinutes: Int
    var remMinutes: Int
    var awakeMinutes: Int
    var efficiency: Double  // 0–1

    var totalHours: Double { Double(totalMinutes) / 60.0 }
}

struct SleepSummary {
    var avgHours: Double
    var efficiency: Double    // percentage, e.g. 95
    var avgAwakeCount: Double
    var avgDeepMinutes: Double
    var avgRemMinutes: Double
    var avgCoreMinutes: Double
    var avgAwakeMinutes: Double
}

// MARK: - Exercise Model

struct ExerciseMonth: Identifiable {
    var id: String { label }
    var label: String       // "1月", "2月" …
    var totalKcal: Int
    var avgHR: Double
    var sessions: Int
    var activeDays: Int
}

struct ExerciseSummary {
    var dailyKcalAvg: Int
    var dailyMinAvg: Int
    var avgAeroHR: Int
    var totalKcalCumulative: Int
    var fatBurnedKg: Double
    var mainTimeOfDay: String   // "中午"
    var aeroPercent: Int        // 66
    var monthlySessions: Double // 27.5
    var monthlyDays: Int        // 15
}

// MARK: - Store

class HealthStore: ObservableObject {
    @Published var events: [HealthEvent] = HealthEvent.mockData
    @Published var weightWeekly: [WeightEntry] = WeightEntry.mockWeekly
    @Published var weightMonthly: [WeightEntry] = WeightEntry.mockMonthly
    @Published var weightYearly: [WeightEntry] = WeightEntry.mockYearly
    @Published var sleepEntries: [SleepEntry] = SleepEntry.mockData
    @Published var exerciseMonths: [ExerciseMonth] = ExerciseMonth.mockData

    let goalWeight: Double = 73.0
    let startWeight: Double = 91.2
    let userName: String = "李"

    var latestWeight: Double { weightWeekly.last?.kg ?? 77.1 }
    var distToGoal: Double { (latestWeight - goalWeight).rounded(toPlaces: 1) }
    var progressPercent: Double {
        let pct = (startWeight - latestWeight) / (startWeight - goalWeight) * 100
        return max(0, min(100, pct))
    }

    var sleepSummary: SleepSummary {
        SleepSummary(avgHours: 7.3, efficiency: 95, avgAwakeCount: 8.3,
                     avgDeepMinutes: 41, avgRemMinutes: 100, avgCoreMinutes: 280, avgAwakeMinutes: 21)
    }

    var exerciseSummary: ExerciseSummary {
        ExerciseSummary(dailyKcalAvg: 434, dailyMinAvg: 68, avgAeroHR: 121,
                        totalKcalCumulative: 39500, fatBurnedKg: 5.1,
                        mainTimeOfDay: "中午", aeroPercent: 66,
                        monthlySessions: 27.5, monthlyDays: 15)
    }

    func addEvent(_ event: HealthEvent) {
        events.insert(event, at: 0)
    }

    func events(in range: ClosedRange<Date>) -> [HealthEvent] {
        events.filter { range.contains($0.date) }
    }
}

// MARK: - Double helper

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

// MARK: - Mock Data

extension HealthEvent {
    static let mockData: [HealthEvent] = [
        HealthEvent(id: "e1", type: .travel,  title: "出差 · 上海",
                    date: date("2026-06-10"), endDate: date("2026-06-14"),
                    note: "作息紊乱，运动暂停"),
        HealthEvent(id: "e2", type: .drink,   title: "饮酒 · 聚餐",
                    date: date("2026-06-07"), endDate: nil,
                    note: "深睡下降，效率降到 88%"),
        HealthEvent(id: "e3", type: .illness, title: "感冒发烧",
                    date: date("2026-05-31"), endDate: date("2026-06-06"),
                    note: "已就医，停训一周，体重回升 0.6kg"),
        HealthEvent(id: "e4", type: .injury,  title: "腰肌肉拉伤",
                    date: date("2026-05-20"), endDate: date("2026-05-27"),
                    note: "停训一周，周消耗降到平时 1/3"),
    ]
}

extension WeightEntry {
    // Weekly entries (subset — last 16 weeks shown in 周 view)
    static let mockWeekly: [WeightEntry] = [
        WeightEntry(date: "2026-01-05", kg: 80.87),
        WeightEntry(date: "2026-01-12", kg: 81.10),
        WeightEntry(date: "2026-01-26", kg: 81.60),
        WeightEntry(date: "2026-02-02", kg: 81.40),
        WeightEntry(date: "2026-03-23", kg: 83.83),
        WeightEntry(date: "2026-03-30", kg: 83.40),
        WeightEntry(date: "2026-04-06", kg: 82.80),
        WeightEntry(date: "2026-04-13", kg: 82.60),
        WeightEntry(date: "2026-04-20", kg: 82.58),
        WeightEntry(date: "2026-05-04", kg: 81.85),
        WeightEntry(date: "2026-05-11", kg: 81.62),
        WeightEntry(date: "2026-05-18", kg: 80.58),
        WeightEntry(date: "2026-05-25", kg: 79.56),
        WeightEntry(date: "2026-06-01", kg: 78.90),
        WeightEntry(date: "2026-06-08", kg: 78.00),
        WeightEntry(date: "2026-06-15", kg: 77.07),
    ]

    // Monthly aggregates (last 12 months)
    static let mockMonthly: [WeightEntry] = [
        WeightEntry(date: "2025-07-15", kg: 75.3),
        WeightEntry(date: "2025-08-15", kg: 75.0),
        WeightEntry(date: "2025-09-15", kg: 75.5),
        WeightEntry(date: "2025-10-15", kg: 78.6),
        WeightEntry(date: "2025-11-15", kg: 81.3),
        WeightEntry(date: "2025-12-15", kg: 81.6),
        WeightEntry(date: "2026-01-15", kg: 81.2),
        WeightEntry(date: "2026-02-15", kg: 81.4),
        WeightEntry(date: "2026-03-15", kg: 83.6),
        WeightEntry(date: "2026-04-15", kg: 82.7),
        WeightEntry(date: "2026-05-15", kg: 80.9),
        WeightEntry(date: "2026-06-15", kg: 78.0),
    ]

    // Yearly averages
    static let mockYearly: [WeightEntry] = [
        WeightEntry(date: "2019-07-01", kg: 77.2),
        WeightEntry(date: "2020-07-01", kg: 76.0),
        WeightEntry(date: "2022-07-01", kg: 84.9),
        WeightEntry(date: "2023-07-01", kg: 82.8),
        WeightEntry(date: "2024-07-01", kg: 84.2),
        WeightEntry(date: "2025-07-01", kg: 79.4),
        WeightEntry(date: "2026-04-01", kg: 81.1),
    ]
}

extension SleepEntry {
    // 14 nightly entries: June 4–17, 2026
    static let mockData: [SleepEntry] = [
        SleepEntry(date: "2026-06-04", totalMinutes: 429, deepMinutes: 38, coreMinutes: 278, remMinutes: 95,  awakeMinutes: 18, efficiency: 0.96),
        SleepEntry(date: "2026-06-05", totalMinutes: 436, deepMinutes: 42, coreMinutes: 281, remMinutes: 98,  awakeMinutes: 15, efficiency: 0.97),
        SleepEntry(date: "2026-06-06", totalMinutes: 515, deepMinutes: 55, coreMinutes: 335, remMinutes: 110, awakeMinutes: 15, efficiency: 0.97),
        // Drink night — lower deep/efficiency
        SleepEntry(date: "2026-06-07", totalMinutes: 464, deepMinutes: 22, coreMinutes: 310, remMinutes: 102, awakeMinutes: 30, efficiency: 0.88),
        SleepEntry(date: "2026-06-08", totalMinutes: 392, deepMinutes: 30, coreMinutes: 258, remMinutes: 85,  awakeMinutes: 19, efficiency: 0.95),
        SleepEntry(date: "2026-06-09", totalMinutes: 446, deepMinutes: 40, coreMinutes: 290, remMinutes: 99,  awakeMinutes: 17, efficiency: 0.96),
        // Travel period begins — lighter sleep
        SleepEntry(date: "2026-06-10", totalMinutes: 389, deepMinutes: 28, coreMinutes: 248, remMinutes: 88,  awakeMinutes: 25, efficiency: 0.90),
        SleepEntry(date: "2026-06-11", totalMinutes: 497, deepMinutes: 45, coreMinutes: 324, remMinutes: 108, awakeMinutes: 20, efficiency: 0.96),
        SleepEntry(date: "2026-06-12", totalMinutes: 487, deepMinutes: 43, coreMinutes: 316, remMinutes: 105, awakeMinutes: 23, efficiency: 0.95),
        SleepEntry(date: "2026-06-13", totalMinutes: 398, deepMinutes: 26, coreMinutes: 252, remMinutes: 90,  awakeMinutes: 30, efficiency: 0.90),
        SleepEntry(date: "2026-06-14", totalMinutes: 438, deepMinutes: 35, coreMinutes: 282, remMinutes: 97,  awakeMinutes: 24, efficiency: 0.93),
        // Travel ends
        SleepEntry(date: "2026-06-15", totalMinutes: 389, deepMinutes: 33, coreMinutes: 252, remMinutes: 86,  awakeMinutes: 18, efficiency: 0.95),
        SleepEntry(date: "2026-06-16", totalMinutes: 446, deepMinutes: 41, coreMinutes: 290, remMinutes: 98,  awakeMinutes: 17, efficiency: 0.96),
        SleepEntry(date: "2026-06-17", totalMinutes: 335, deepMinutes: 28, coreMinutes: 218, remMinutes: 71,  awakeMinutes: 18, efficiency: 0.94),
    ]
}

extension ExerciseMonth {
    static let mockData: [ExerciseMonth] = [
        ExerciseMonth(label: "1月", totalKcal: 6822,  avgHR: 135.3, sessions: 22, activeDays: 12),
        ExerciseMonth(label: "2月", totalKcal: 822,   avgHR: 150.3, sessions: 3,  activeDays: 2),  // low — illness
        ExerciseMonth(label: "3月", totalKcal: 4899,  avgHR: 130.4, sessions: 18, activeDays: 10),
        ExerciseMonth(label: "4月", totalKcal: 8362,  avgHR: 122.6, sessions: 28, activeDays: 16),
        ExerciseMonth(label: "5月", totalKcal: 14841, avgHR: 115.9, sessions: 35, activeDays: 20), // injury in late May
        ExerciseMonth(label: "6月", totalKcal: 3714,  avgHR: 109.9, sessions: 12, activeDays: 8),  // partial month
    ]
}
