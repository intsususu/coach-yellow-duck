// CheckInStore.swift
// 自律打卡的本机持久化，存于 App Group 共享容器，供主 App 与 Widget extension 共读写。
// 仅本机存储，无网络（AGENTS §5）。独立于事件 EventStore，不参与 2.0「事件大迁移」。
//
// 共享文件：同时编入主 App 与 Widget extension。

import Foundation

/// 一条打卡记录：某打卡日完成了某任务。
struct CheckInRecord: Codable, Hashable {
    var day: Date          // 打卡日（00:00，由 SelfDisciplineSchedule.effectiveDay 归一）
    var task: CheckInTask
}

/// 自律打卡存储。读写 App Group 下的 JSON。
struct CheckInStore {
    /// App Group 标识；主 App 与 Widget 的 entitlements 必须一致。
    static let appGroupID = "group.com.xltc.sdlyc"
    static let storageKey = "selfdiscipline.checkins.v1"
    /// 每周每项目标打卡次数（达成视为当周 100%）的存储键。
    static let weeklyTargetsKey = "selfdiscipline.weeklytargets.v1"

    /// 运动「疲劳管理」阈值：本周打卡超过 5 次即提示。
    static let exerciseFatigueThreshold = 5

    /// 每周目标次数的允许范围（1～7 次/周）与默认值。
    static let weeklyTargetRange = 1...7
    static let defaultWeeklyTarget = 7

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults? = nil, calendar: Calendar = SelfDisciplineSchedule.calendar) {
        self.defaults = defaults ?? UserDefaults(suiteName: Self.appGroupID) ?? .standard
        self.calendar = calendar
    }

    // MARK: - 读

    func load() -> [CheckInRecord] {
        guard let data = defaults.data(forKey: Self.storageKey),
              let records = try? JSONDecoder().decode([CheckInRecord].self, from: data) else {
            return []
        }
        return records
    }

    /// 某打卡日的某任务是否已打卡。
    func isChecked(_ task: CheckInTask, on day: Date) -> Bool {
        let key = calendar.startOfDay(for: day)
        return load().contains { $0.task == task && calendar.isDate($0.day, inSameDayAs: key) }
    }

    /// 某打卡日已完成的任务数（0...3）。
    func completedCount(on day: Date) -> Int {
        CheckInTask.allCases.filter { isChecked($0, on: day) }.count
    }

    /// 某打卡日三项任务的完成状态。
    func states(on day: Date) -> [CheckInTask: Bool] {
        let key = calendar.startOfDay(for: day)
        let records = load()
        return Dictionary(uniqueKeysWithValues: CheckInTask.allCases.map { task in
            let checked = records.contains { $0.task == task && calendar.isDate($0.day, inSameDayAs: key) }
            return (task, checked)
        })
    }

    /// 给定打卡日所在自然周内，某任务的打卡次数。
    func weeklyCount(_ task: CheckInTask, weekContaining day: Date) -> Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: day) else { return 0 }
        return load().filter {
            $0.task == task && interval.contains($0.day)
        }.count
    }

    /// 运动时段是否应提示「注意疲劳管理」：本周运动打卡 > 阈值。
    func shouldWarnFatigue(on day: Date) -> Bool {
        weeklyCount(.exercise, weekContaining: day) > Self.exerciseFatigueThreshold
    }

    /// 某任务在「day 所属自然周」的周一~周日打卡情况（7 个，周一在前）。
    func weekMarks(_ task: CheckInTask, weekContaining day: Date) -> [Bool] {
        let start = SelfDisciplineSchedule.weekStart(for: day, calendar: calendar)
        return (0..<7).map { offset in
            guard let d = calendar.date(byAdding: .day, value: offset, to: start) else { return false }
            return isChecked(task, on: d)
        }
    }

    /// 三个任务在 `day` 所属自然周的周一~周日记录（用于非时段汇总卡）。
    func currentWeekRows(weekContaining day: Date) -> [(task: CheckInTask, marks: [Bool])] {
        CheckInTask.allCases.map { ($0, weekMarks($0, weekContaining: day)) }
    }

    /// 最近 `dayCount` 个打卡日的网格：每个任务一行，按日期升序的已打卡布尔序列。
    func grid(dayCount: Int, endingAt now: Date = Date()) -> [(task: CheckInTask, marks: [Bool])] {
        let days = SelfDisciplineSchedule.recentDays(dayCount, endingAt: now, calendar: calendar)
        let records = load()
        return CheckInTask.allCases.map { task in
            let marks = days.map { day in
                records.contains { $0.task == task && calendar.isDate($0.day, inSameDayAs: day) }
            }
            return (task, marks)
        }
    }

    // MARK: - 每周目标次数

    /// 某任务的每周目标打卡次数（达成即当周 100%）。未配置时取默认值，并夹到允许范围。
    func weeklyTarget(for task: CheckInTask) -> Int {
        let stored = loadWeeklyTargets()[task.rawValue] ?? Self.defaultWeeklyTarget
        return min(max(stored, Self.weeklyTargetRange.lowerBound), Self.weeklyTargetRange.upperBound)
    }

    /// 设置某任务的每周目标打卡次数（自动夹到 1～7）。
    func setWeeklyTarget(_ count: Int, for task: CheckInTask) {
        let clamped = min(max(count, Self.weeklyTargetRange.lowerBound), Self.weeklyTargetRange.upperBound)
        var targets = loadWeeklyTargets()
        targets[task.rawValue] = clamped
        guard let data = try? JSONEncoder().encode(targets) else { return }
        defaults.set(data, forKey: Self.weeklyTargetsKey)
    }

    private func loadWeeklyTargets() -> [String: Int] {
        guard let data = defaults.data(forKey: Self.weeklyTargetsKey),
              let targets = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return targets
    }

    // MARK: - 写

    /// 切换某任务在「now 所属打卡日」的打卡状态；返回切换后的「已打卡」结果。
    @discardableResult
    func toggle(_ task: CheckInTask, at now: Date = Date()) -> Bool {
        let day = SelfDisciplineSchedule.effectiveDay(for: now, calendar: calendar)
        var records = load()
        if let index = records.firstIndex(where: { $0.task == task && calendar.isDate($0.day, inSameDayAs: day) }) {
            records.remove(at: index)
            persist(records)
            return false
        } else {
            records.append(CheckInRecord(day: day, task: task))
            persist(records)
            return true
        }
    }

    /// 设置某打卡日的某任务状态，用于 App 内历史编辑。
    func set(_ task: CheckInTask, checked: Bool, on day: Date) {
        let key = calendar.startOfDay(for: day)
        var records = load()
        if let index = records.firstIndex(where: { $0.task == task && calendar.isDate($0.day, inSameDayAs: key) }) {
            if !checked {
                records.remove(at: index)
            }
        } else if checked {
            records.append(CheckInRecord(day: key, task: task))
        }
        persist(records)
    }

    /// 批量设置同一任务的多个打卡日；用于自动运动打卡，避免逐日反复解码/写入 JSON。
    @discardableResult
    func set(_ task: CheckInTask, checked: Bool, on days: Set<Date>) -> Bool {
        let keys = Set(days.map { calendar.startOfDay(for: $0) })
        guard !keys.isEmpty else { return false }

        var records = load()
        var changed = false

        if checked {
            for day in keys where !records.contains(where: { $0.task == task && calendar.isDate($0.day, inSameDayAs: day) }) {
                records.append(CheckInRecord(day: day, task: task))
                changed = true
            }
        } else {
            let oldCount = records.count
            records.removeAll { record in
                record.task == task && keys.contains(calendar.startOfDay(for: record.day))
            }
            changed = records.count != oldCount
        }

        if changed {
            persist(records)
        }
        return changed
    }

    private func persist(_ records: [CheckInRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
