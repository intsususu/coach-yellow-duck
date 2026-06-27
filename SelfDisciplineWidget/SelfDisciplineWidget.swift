// SelfDisciplineWidget.swift
// 自律打卡桌面小组件：正方形（按时段配插图背景 + 本周记录）与长条（本月日历）两种尺寸，iOS 17 交互式打卡。

import WidgetKit
import SwiftUI
import AppIntents
import UIKit

// MARK: - 任务的小组件主题（背景资源 + 兜底渐变 + 角标）

extension CheckInTask {
    /// 背景插图资源名（放在 Widget 的 Assets.xcassets；缺图时走渐变兜底）。
    var bgAssetName: String {
        switch self {
        case .exercise:  return "bg_exercise"
        case .noSnack:   return "bg_noSnack"
        case .readSleep: return "bg_readSleep"
        }
    }

    /// 无插图时的兜底渐变。
    var fallbackGradient: [Color] {
        switch self {
        case .exercise:  return [.brandBlue, .sleepIndigo]
        case .noSnack:   return [.sleepDeep, .textPrimary]
        case .readSleep: return [.sleepIndigo, .sleepDeep]
        }
    }

    /// Widget 原型专用任务色：夜宵为绿色，避免影响 App 内共享卡片色。
    var widgetTint: Color {
        switch self {
        case .exercise:  return .exerciseOrange
        case .noSnack:   return .successGreen
        case .readSleep: return .sleepIndigo
        }
    }

    /// 右上角时段角标。
    var cornerSymbol: String {
        switch self {
        case .exercise:  return "sun.max.fill"
        case .noSnack:   return "moon.fill"
        case .readSleep: return "moon.stars.fill"
        }
    }
}

private let weekdayLabels = ["一", "二", "三", "四", "五", "六", "日"]

// MARK: - Timeline 条目与 Provider

struct CheckInEntry: TimelineEntry {
    let date: Date
    let snapshot: SelfDisciplineSnapshot
    let activeWeekMarks: [Bool]   // 当前任务本周一~日
    let activeWeekCount: Int
    let todayIndex: Int           // 今天在本周的列（0=周一 … 6=周日）
    let weekRows: [(task: CheckInTask, marks: [Bool])]   // 三任务本周一~日（非时段汇总）
    let monthRows: [(task: CheckInTask, marks: [Bool])]  // 本月每一天（中号日历）
    let monthOffset: Int         // 本月 1 日在周历中的前置空格（0=周一）
    let todayMonthDayIndex: Int  // 今天在本月的索引（0-based）
}

struct CheckInProvider: TimelineProvider {
    private func entry(for date: Date) -> CheckInEntry {
        let store = CheckInStore()
        let snap = SelfDisciplineSnapshot.make(now: date, store: store)
        let cal = SelfDisciplineSchedule.calendar
        let weekday = cal.component(.weekday, from: snap.today) // 1=周日 … 7=周六
        let todayIndex = (weekday + 5) % 7                       // 0=周一 … 6=周日
        let activeMarks = snap.activeTask.map { store.weekMarks($0, weekContaining: snap.today) } ?? []
        let month = Self.monthRows(store: store, today: snap.today, calendar: cal)
        return CheckInEntry(
            date: date,
            snapshot: snap,
            activeWeekMarks: activeMarks,
            activeWeekCount: activeMarks.filter { $0 }.count,
            todayIndex: todayIndex,
            weekRows: store.currentWeekRows(weekContaining: snap.today),
            monthRows: month.rows,
            monthOffset: month.offset,
            todayMonthDayIndex: month.todayIndex
        )
    }

    private static func monthRows(store: CheckInStore,
                                  today: Date,
                                  calendar cal: Calendar) -> (rows: [(task: CheckInTask, marks: [Bool])],
                                                               offset: Int,
                                                               todayIndex: Int) {
        let components = cal.dateComponents([.year, .month, .day], from: today)
        guard let firstDay = cal.date(from: DateComponents(year: components.year, month: components.month, day: 1)),
              let dayRange = cal.range(of: .day, in: .month, for: firstDay) else {
            return ([], 0, 0)
        }

        let firstWeekday = cal.component(.weekday, from: firstDay)
        let offset = (firstWeekday + 5) % 7
        let days = dayRange.compactMap { day -> Date? in
            cal.date(from: DateComponents(year: components.year, month: components.month, day: day))
        }
        let rows = CheckInTask.allCases.map { task in
            (task, days.map { store.isChecked(task, on: $0) })
        }

        return (rows, offset, max((components.day ?? 1) - 1, 0))
    }

    func placeholder(in context: Context) -> CheckInEntry { entry(for: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (CheckInEntry) -> Void) {
        completion(entry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CheckInEntry>) -> Void) {
        let now = Date()
        let policy: TimelineReloadPolicy = .after(Self.nextBoundary(after: now))
        completion(Timeline(entries: [entry(for: now)], policy: policy))
    }

    /// 三个时段所有起止点中，晚于 `date` 的最近一个时刻。
    static func nextBoundary(after date: Date) -> Date {
        let cal = SelfDisciplineSchedule.calendar
        let boundaryMinutes = CheckInTask.allCases.flatMap { [$0.window.start, $0.window.end] }
        let startOfToday = cal.startOfDay(for: date)
        let candidates = (0...1).flatMap { dayOffset -> [Date] in
            guard let base = cal.date(byAdding: .day, value: dayOffset, to: startOfToday) else { return [] }
            return boundaryMinutes.compactMap { cal.date(byAdding: .minute, value: $0, to: base) }
        }
        return candidates.filter { $0 > date }.min() ?? date.addingTimeInterval(3600)
    }
}

// MARK: - 背景

struct SelfDisciplineBackground: View {
    @Environment(\.widgetFamily) private var family
    let entry: CheckInEntry

    /// 非时段中性卡的插图资源名。
    static let neutralWeekdayAssetName = "bg_weekday"
    static let neutralWeekendAssetName = "bg_default"

    var body: some View {
        // 小号与中号都按原型使用白底插图卡，只有插图缺失时才落到柔和渐变。
        if let task = entry.snapshot.activeTask {
            lightImageCard(asset: task.bgAssetName, fallbackTint: task.widgetTint, cornerSymbol: task.cornerSymbol)
        } else {
            lightImageCard(asset: neutralAssetName, fallbackTint: .brandBlue, cornerSymbol: "sparkles")
        }
    }

    private var neutralAssetName: String {
        entry.todayIndex >= 5 ? Self.neutralWeekendAssetName : Self.neutralWeekdayAssetName
    }

    // 白底浅色卡 + 插图（白底）+ 左侧白色渐变，保证左栏深色文字清晰。
    @ViewBuilder
    private func lightImageCard(asset: String, fallbackTint: Color, cornerSymbol: String) -> some View {
        ZStack {
            Color.cardBg

            GeometryReader { proxy in
                if let image = UIImage(named: asset) {
                    let targetImageSize = imageSize
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: targetImageSize, height: targetImageSize)
                        .position(imagePosition(in: proxy.size, imageSize: targetImageSize))
                } else {
                    LinearGradient(colors: [.cardBg, fallbackTint.opacity(0.18)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: cornerSymbol)
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(fallbackTint.opacity(0.35))
                                .padding(14)
                        }
                }
            }

            imageFade
        }
    }

    private var imageSize: CGFloat {
        family == .systemMedium ? 147 : 129
    }

    private func imagePosition(in size: CGSize, imageSize: CGFloat) -> CGPoint {
        if family == .systemMedium {
            return CGPoint(x: size.width - 157 - imageSize / 2 + imageSize * 0.1, y: size.height / 2)
        }
        return CGPoint(x: size.width + 35 - imageSize / 2,
                       y: size.height / 2 - 10)
            .applying(CGAffineTransform(translationX: -imageSize * 0.2, y: 0))
    }

    private var imageFade: some View {
        let stops: [Gradient.Stop] = family == .systemMedium
            ? [
                .init(color: .white.opacity(0.95), location: 0.0),
                .init(color: .white.opacity(0.90), location: 0.18),
                .init(color: .white.opacity(0.0), location: 0.40)
            ]
            : [
                .init(color: .white.opacity(0.96), location: 0.0),
                .init(color: .white.opacity(0.78), location: 0.26),
                .init(color: .white.opacity(0.0), location: 0.50)
            ]
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
    }
}

// MARK: - 打卡记录组件

/// 单任务：周一~周日 7 格（带星期文字），用于激活态正方形卡。
struct WeekRecordRow: View {
    let tint: Color
    let marks: [Bool]
    let todayIndex: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                VStack(spacing: 2) {
                    Text(weekdayLabels[i])
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.textSecondary)
                    cell(checked: marks.indices.contains(i) && marks[i], isToday: i == todayIndex)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 4)
        .background(Color.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder private func cell(checked: Bool, isToday: Bool) -> some View {
        if checked {
            Image(systemName: "checkmark")
                .font(.system(size: 8, weight: .heavy))
                .foregroundColor(.white)
                .frame(width: 15, height: 15)
                .background(tint, in: Circle())
        } else {
            Circle()
                .stroke(isToday ? tint : Color.textMuted.opacity(0.5), lineWidth: isToday ? 1.8 : 1.2)
                .frame(width: 15, height: 15)
        }
    }
}

/// 中号右侧：本月日历打卡记录。
struct MonthCheckInCalendar: View {
    let marks: [Bool]
    let tint: Color
    let monthOffset: Int
    let todayDayIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("本月打卡")
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.textSecondary)

            HStack(spacing: 3) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 7.5, weight: .heavy))
                        .foregroundColor(.textMuted)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(0..<cellCount, id: \.self) { index in
                    calendarCell(at: index)
                }
            }
        }
        .frame(width: 120)
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)
    }

    private var cellCount: Int {
        let rawCount = max(35, monthOffset + marks.count)
        return ((rawCount + 6) / 7) * 7
    }

    @ViewBuilder
    private func calendarCell(at index: Int) -> some View {
        let dayIndex = index - monthOffset
        if dayIndex < 0 || dayIndex >= marks.count {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
        } else {
            let isOn = marks[dayIndex]
            let isToday = dayIndex == todayDayIndex
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(isOn ? tint : Color.textMuted.opacity(0.16))
                .overlay {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(tint, lineWidth: isToday ? 1.5 : 0)
                }
                .aspectRatio(1, contentMode: .fit)
        }
    }
}

// MARK: - 视图主体

struct SelfDisciplineEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CheckInEntry

    var body: some View {
        // 整卡点击跳转「我的 → 自律打卡」；唯一的例外是「打卡」按钮（交互式 App Intent，
        // 命中按钮时优先触发其打卡动作，不会走 widgetURL）。
        content
            .padding(.horizontal, 13)
            .padding(.top, 13)
            .padding(.bottom, 9)
            .widgetURL(SelfDisciplineDeepLink.url)
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .systemMedium: mediumBody
        default:            smallBody
        }
    }

    // 正方形：插图背景 + 标题/副标题 + 打卡 + 本周记录
    @ViewBuilder private var smallBody: some View {
        if let task = entry.snapshot.activeTask {
            VStack(alignment: .leading, spacing: 0) {
                Text(task.windowText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.textSecondary)

                Spacer(minLength: 4)

                Text(task.cardTitle)
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(task.widgetTint)
                    .lineLimit(1)
                if entry.snapshot.showsFatigueWarning {
                    Text(SelfDisciplineSnapshot.fatigueMessage)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(task.widgetTint)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                checkButton(for: task)

                Spacer(minLength: 8)

                WeekRecordRow(tint: task.widgetTint, marks: entry.activeWeekMarks, todayIndex: entry.todayIndex)
            }
        } else {
            neutralSmall
        }
    }

    // 非时段：与激活态同布局（白底插图卡）。左上「自律打卡」+ 下方本周累计 XX/YY，无其它统计。
    private var neutralSmall: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(" ")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.textSecondary)

            Spacer(minLength: 4)

            Text("自律打卡")
                .font(.system(size: 18, weight: .black))
                .foregroundColor(.textMuted)
                .lineLimit(1)

            Spacer(minLength: 6)

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(entry.snapshot.weekDone)")
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(.successGreen)
                Text("/\(entry.snapshot.weekExpected)")
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(.textMuted)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            Spacer(minLength: 8)

            WeekRecordRow(tint: .textMuted, marks: neutralWeekMarks, todayIndex: entry.todayIndex)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 长条：左侧复用小号信息层级，右侧是本月日历打卡记录。
    private var mediumBody: some View {
        HStack(alignment: .center, spacing: 12) {
            mediumMain
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            MonthCheckInCalendar(
                marks: monthMarks,
                tint: entry.snapshot.activeTask?.widgetTint ?? .textMuted,
                monthOffset: entry.monthOffset,
                todayDayIndex: entry.todayMonthDayIndex
            )
        }
    }

    @ViewBuilder private var mediumMain: some View {
        if let task = entry.snapshot.activeTask {
            VStack(alignment: .leading, spacing: 0) {
                Text(task.windowText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.textSecondary)

                Spacer(minLength: 4)

                Text(task.cardTitle)
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(task.widgetTint)
                    .lineLimit(1)

                if entry.snapshot.showsFatigueWarning {
                    Text(SelfDisciplineSnapshot.fatigueMessage)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(task.widgetTint)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                checkButton(for: task)

                Spacer(minLength: 8)

                WeekRecordRow(tint: task.widgetTint, marks: entry.activeWeekMarks, todayIndex: entry.todayIndex)
                    .hidden()
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text(" ")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.textSecondary)

                Spacer(minLength: 4)

                Text("自律打卡")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.textMuted)
                    .lineLimit(1)

                Spacer(minLength: 6)

                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(entry.snapshot.weekDone)")
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(.successGreen)
                    Text("/\(entry.snapshot.weekExpected)")
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(.textMuted)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)

                Spacer(minLength: 8)

                WeekRecordRow(tint: .textMuted, marks: neutralWeekMarks, todayIndex: entry.todayIndex)
                    .hidden()
            }
        }
    }

    private var neutralWeekMarks: [Bool] {
        guard let first = entry.weekRows.first?.marks else { return Array(repeating: false, count: 7) }
        return first.indices.map { index in
            entry.weekRows.contains { row in
                row.marks.indices.contains(index) && row.marks[index]
            }
        }
    }

    private var monthMarks: [Bool] {
        if let task = entry.snapshot.activeTask,
           let row = entry.monthRows.first(where: { $0.task == task }) {
            return row.marks
        }
        guard let first = entry.monthRows.first?.marks else { return [] }
        return first.indices.map { index in
            entry.monthRows.contains { row in
                row.marks.indices.contains(index) && row.marks[index]
            }
        }
    }

    // 白色胶囊打卡按钮（交互式 App Intent）：贴合内容、左对齐的小胶囊
    private func checkButton(for task: CheckInTask) -> some View {
        let checked = entry.snapshot.activeChecked
        return Button(intent: CheckInIntent(task: task)) {
            HStack(spacing: 3) {
                Text("打卡")
                ZStack {
                    Circle()
                        .fill(checked ? task.widgetTint : Color.clear)
                    Circle()
                        .stroke(task.widgetTint, lineWidth: 1.4)
                    if checked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .heavy))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 11, height: 11)
            }
            .font(.system(size: 11, weight: .heavy))
            .foregroundColor(task.widgetTint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4.5)
            .background(.white, in: Capsule())
            .overlay(Capsule().stroke(task.widgetTint.opacity(checked ? 0.9 : 0.45), lineWidth: 1.2))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Widget 定义

struct SelfDisciplineWidget: Widget {
    let kind = "SelfDisciplineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CheckInProvider()) { entry in
            SelfDisciplineEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    SelfDisciplineBackground(entry: entry)
                }
        }
        .contentMarginsDisabled()
        .configurationDisplayName("自律打卡")
        .description("按时段打卡运动 / 别吃夜宵 / 阅读早睡，查看本周记录或本月日历。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
