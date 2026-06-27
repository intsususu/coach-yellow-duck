// SelfDisciplineModel.swift
// 自律打卡：三个固定时段的打卡任务模型与时段/自然周判定逻辑。
// 暂不支持自定义；时段、文案、规则均写死（docs/2.0-planning.md §4）。
//
// 共享文件：同时编入主 App 与 Widget extension（两个 target 均勾选）。
// 当日边界在 00:30：23:30–00:30「阅读早睡」算同一天，凌晨打卡归前一天。

import Foundation

/// 自律打卡深链：点击桌面小组件空白区域跳转「我的 → 自律打卡」。
/// 单一来源，App 与 Widget 两端共用，避免字符串写错对不上。
enum SelfDisciplineDeepLink {
    /// 自定义 scheme 链接。Widget 内的链接由系统直接投递给宿主 App，无需在 Info.plist 注册 scheme。
    static let url = URL(string: "coachduck://self-discipline")!

    /// 判断一个被 onOpenURL 接收的链接是否为「打开自律打卡」。
    static func matches(_ incoming: URL) -> Bool {
        incoming.scheme == url.scheme && incoming.host == url.host
    }
}

/// 自律打卡任务（三个固定时段）。
enum CheckInTask: String, CaseIterable, Codable, Identifiable {
    case exercise    // 运动
    case noSnack     // 别吃夜宵
    case readSleep   // 阅读早睡

    var id: String { rawValue }

    var title: String {
        switch self {
        case .exercise:  return "运动"
        case .noSnack:   return "别吃夜宵"
        case .readSleep: return "阅读早睡"
        }
    }

    var iconName: String {
        switch self {
        case .exercise:  return "figure.run"
        case .noSnack:   return "moon.zzz.fill"
        case .readSleep: return "book.fill"
        }
    }

    /// 卡片标题（比 title 更具场景感，用于小组件大标题）。
    var cardTitle: String {
        switch self {
        case .exercise:  return "运动时间"
        case .noSnack:   return "别吃夜宵"
        case .readSleep: return "阅读早睡"
        }
    }

    /// 卡片副标题。
    var subtitle: String {
        switch self {
        case .exercise:  return "动起来，活力满满"
        case .noSnack:   return "管住嘴，睡得更好"
        case .readSleep: return "放下手机，准备入睡"
        }
    }

    /// 时段起止，用「自 00:00 起的分钟数」表示。
    /// readSleep 跨午夜（end < start）：23:30 → 次日 00:30。
    var window: (start: Int, end: Int) {
        switch self {
        case .exercise:  return (11 * 60, 13 * 60)            // 11:00–13:00
        case .noSnack:   return (20 * 60 + 30, 22 * 60 + 30)  // 20:30–22:30
        case .readSleep: return (23 * 60 + 30, 30)            // 23:30–次日 00:30
        }
    }

    /// 时段文字，如「11:00–13:00」。
    var windowText: String {
        let (s, e) = window
        return "\(Self.hhmm(s))–\(Self.hhmm(e))"
    }

    private static func hhmm(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

/// 自律打卡的时间判定：当日边界 00:30、自然周（周一起）、当前激活时段。
enum SelfDisciplineSchedule {
    /// 当日边界（分钟）：< 00:30 归前一天。
    static let dayBoundaryMinutes = 30

    /// 统一日历：周一为一周起点，UTC+8 对齐本机时区。
    static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday
        cal.timeZone = .current
        return cal
    }

    /// 某时刻所属的「打卡日」（归一到 00:00；边界 00:30 之前算前一天）。
    static func effectiveDay(for date: Date, calendar cal: Calendar = calendar) -> Date {
        let shifted = date.addingTimeInterval(TimeInterval(-dayBoundaryMinutes * 60))
        return cal.startOfDay(for: shifted)
    }

    /// 当前时刻处于哪个打卡时段；不在任何时段返回 nil。
    static func activeTask(at date: Date = Date(), calendar cal: Calendar = calendar) -> CheckInTask? {
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        return CheckInTask.allCases.first { task in
            let (s, e) = task.window
            if s <= e {
                return minutes >= s && minutes < e         // 同日时段
            } else {
                return minutes >= s || minutes < e         // 跨午夜时段
            }
        }
    }

    /// 给定打卡日所在自然周的周一（00:00）。
    static func weekStart(for effectiveDay: Date, calendar cal: Calendar = calendar) -> Date {
        cal.dateInterval(of: .weekOfYear, for: effectiveDay)?.start ?? effectiveDay
    }

    /// 从 `now` 往前数 `count` 个打卡日，按时间升序（最早 → 今天）。
    static func recentDays(_ count: Int, endingAt now: Date = Date(), calendar cal: Calendar = calendar) -> [Date] {
        let today = effectiveDay(for: now, calendar: cal)
        return (0..<count).reversed().compactMap { offset in
            cal.date(byAdding: .day, value: -offset, to: today)
        }
    }
}
