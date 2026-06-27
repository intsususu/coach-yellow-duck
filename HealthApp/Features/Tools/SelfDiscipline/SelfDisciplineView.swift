// SelfDisciplineView.swift
// 自律打卡 App 内页面：默认月历视图展示当月每天三项打卡状态，点击日期可编辑历史打卡。
// 数据走共享 CheckInStore（App Group），与 Widget 互通。

import SwiftUI
import WidgetKit

struct SelfDisciplineView: View {
    private let store = CheckInStore()
    private let calendar = SelfDisciplineSchedule.calendar
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let autoExerciseThresholdMinutes = 30

    @State private var visibleMonth: Date
    @State private var selectedDay: Date
    @State private var draftStates: [CheckInTask: Bool] = [:]
    @State private var autoExerciseDays: Set<Date> = []
    @State private var recordKeys: Set<CheckInRecordKey> = []
    /// 每次写入后自增以触发重算（CheckInStore 为值类型，无自动发布）。
    @State private var revision = 0
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appState: AppState

    init(now: Date = Date()) {
        let day = SelfDisciplineSchedule.effectiveDay(for: now)
        _selectedDay = State(initialValue: day)
        _visibleMonth = State(initialValue: Self.startOfMonth(for: day))
    }

    private var today: Date {
        _ = revision
        return SelfDisciplineSchedule.effectiveDay(for: Date(), calendar: calendar)
    }

    private var isSelectedToday: Bool {
        calendar.isDate(selectedDay, inSameDayAs: today)
    }

    // MARK: - 打卡统计（本周 / 本月完成数，基于今天所在周/月）

    private var weekCompletedCount: Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: today) else { return 0 }
        return recordKeys.filter { interval.contains($0.day) }.count
    }

    private var weekExpectedCount: Int { 7 * CheckInTask.allCases.count }

    private var monthCompletedCount: Int {
        guard let interval = calendar.dateInterval(of: .month, for: today) else { return 0 }
        return recordKeys.filter { interval.contains($0.day) }.count
    }

    private var monthExpectedCount: Int {
        let days = calendar.range(of: .day, in: .month, for: today)?.count ?? 30
        return days * CheckInTask.allCases.count
    }

    private var showsFatigueWarning: Bool {
        SelfDisciplineSchedule.activeTask(at: Date(), calendar: calendar) == .exercise
            && weeklyCount(.exercise, weekContaining: today) > CheckInStore.exerciseFatigueThreshold
    }

    private var monthTitle: String {
        let comps = calendar.dateComponents([.year, .month], from: visibleMonth)
        return "\(comps.year ?? 0)年\(comps.month ?? 1)月"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                statsCard
                monthCalendarCard
                dayEditorCard
                rulesCard
            }
            .padding(16)
        }
        .background(Color.appBg.ignoresSafeArea())
        .navigationTitle("自律打卡")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: selectToday) {
                    Text("今天")
                        .font(.system(size: 14, weight: .bold))
                }
            }
        }
        .onAppear {
            reloadRecordsAndDraft()
        }
        .task {
            await syncAutoExerciseCheckIns()
        }
        .onChange(of: selectedDay) { _ in
            loadDraft()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                revision += 1
                loadDraft()
                Task { await syncAutoExerciseCheckIns() }
            }
        }
    }

    // MARK: - 打卡统计

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("打卡统计")
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(.textPrimary)

            HStack(spacing: 12) {
                statTile(title: "本周完成打卡", value: weekCompletedCount, total: weekExpectedCount)
                statTile(title: "本月完成打卡", value: monthCompletedCount, total: monthExpectedCount)
            }

            if showsFatigueWarning {
                Label(SelfDisciplineSnapshot.fatigueMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.warningAmber)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.warningAmber.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func statTile(title: String, value: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(value)")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(.successGreen)
                Text("/\(total)")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.appBg.opacity(0.65), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - 月历

    private var monthCalendarCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(monthTitle)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(.textPrimary)
                Spacer()
                HStack(spacing: 6) {
                    monthButton(systemName: "chevron.left") { moveMonth(by: -1) }
                    monthButton(systemName: "chevron.right") { moveMonth(by: 1) }
                }
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Self.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.textMuted)
                        .frame(maxWidth: .infinity)
                }

                ForEach(monthDays(for: visibleMonth)) { day in
                    CheckInMonthDayCell(
                        date: day.date,
                        isInVisibleMonth: day.isInVisibleMonth,
                        isToday: calendar.isDate(day.date, inSameDayAs: today),
                        isSelected: calendar.isDate(day.date, inSameDayAs: selectedDay),
                        states: states(on: day.date),
                        dayNumber: calendar.component(.day, from: day.date)
                    ) {
                        select(day.date)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func monthButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(.textPrimary)
                .frame(width: 30, height: 30)
                .background(Color.appBg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 日期编辑

    private var dayEditorCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(monthDayText(selectedDay)) · \(weekdayText(selectedDay))")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(.textPrimary)
                Text(isSelectedToday ? "今天" : "历史打卡")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                ForEach(CheckInTask.allCases) { task in
                    CheckInEditorRow(
                        task: task,
                        detailText: isAutoExercise(task, on: selectedDay) ? "主动运动 ≥30 分钟" : nil,
                        isChecked: Binding(
                            get: { draftStates[task] ?? false },
                            set: { setTask(task, checked: $0) }
                        )
                    )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - 规则说明

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("打卡时段")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.textPrimary)
            ForEach(CheckInTask.allCases) { task in
                HStack(spacing: 8) {
                    Image(systemName: task.iconName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(task.tint)
                        .frame(width: 18)
                    Text(task.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Text(task.windowText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
            }
            Text("运动每周超过 5 次，运动时段将提示「注意疲劳管理」。")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textMuted)
                .padding(.top, 2)
            Text("当天主动运动时长满 30 分钟，会自动完成「运动」打卡；未记录到运动时也可手动补打卡。")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textMuted)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Actions

    private func loadDraft() {
        draftStates = states(on: selectedDay)
    }

    private func reloadRecordsAndDraft(autoDays: Set<Date>? = nil) {
        let keys = Self.recordKeys(from: store.load(), calendar: calendar)
        recordKeys = keys
        draftStates = states(on: selectedDay, using: keys, autoDays: autoDays)
    }

    private func setTask(_ task: CheckInTask, checked: Bool) {
        guard !(task == .exercise && isAutoExercise(task, on: selectedDay) && !checked) else {
            draftStates[task] = true
            return
        }
        guard draftStates[task] != checked else { return }
        draftStates[task] = checked
        let key = CheckInRecordKey(day: normalizedDay(selectedDay), task: task)
        var keys = recordKeys
        if checked {
            keys.insert(key)
        } else {
            keys.remove(key)
        }
        recordKeys = keys
        store.set(task, checked: checked, on: selectedDay)
        revision += 1
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func syncAutoExerciseCheckIns() async {
        let samples = await appState.repository.exerciseMinutesDailyTrend()
        let days = Set(samples.compactMap { sample -> Date? in
            guard sample.value >= Double(autoExerciseThresholdMinutes) else { return nil }
            return normalizedDay(sample.date)
        })
        let changed = store.set(.exercise, checked: true, on: days)
        autoExerciseDays = days
        revision += 1
        reloadRecordsAndDraft(autoDays: days)
        if changed {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func selectToday() {
        select(today)
    }

    private func select(_ day: Date) {
        let normalized = calendar.startOfDay(for: day)
        selectedDay = normalized
        visibleMonth = Self.startOfMonth(for: normalized)
    }

    private func moveMonth(by value: Int) {
        guard let month = calendar.date(byAdding: .month, value: value, to: visibleMonth) else { return }
        visibleMonth = Self.startOfMonth(for: month)
        selectedDay = visibleMonth
    }

    // MARK: - Date helpers

    private func monthDays(for month: Date) -> [CheckInCalendarDay] {
        let firstDay = Self.startOfMonth(for: month)
        let weekday = calendar.component(.weekday, from: firstDay)
        let offset = (weekday + 5) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -offset, to: firstDay) else { return [] }

        return (0..<42).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index, to: gridStart) else { return nil }
            return CheckInCalendarDay(
                date: calendar.startOfDay(for: date),
                isInVisibleMonth: calendar.isDate(date, equalTo: firstDay, toGranularity: .month)
            )
        }
    }

    private func states(on day: Date,
                        using keys: Set<CheckInRecordKey>? = nil,
                        autoDays: Set<Date>? = nil) -> [CheckInTask: Bool] {
        let dayKey = normalizedDay(day)
        let sourceKeys = keys ?? recordKeys
        let sourceAutoDays = autoDays ?? autoExerciseDays
        return Dictionary(uniqueKeysWithValues: CheckInTask.allCases.map { task in
            let checked = sourceKeys.contains(CheckInRecordKey(day: dayKey, task: task))
                || (task == .exercise && sourceAutoDays.contains(dayKey))
            return (task, checked)
        })
    }

    private func isAutoExercise(_ task: CheckInTask, on day: Date) -> Bool {
        task == .exercise && autoExerciseDays.contains(normalizedDay(day))
    }

    private func weeklyCount(_ task: CheckInTask, weekContaining day: Date) -> Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: day) else { return 0 }
        return recordKeys.filter { key in
            key.task == task && interval.contains(key.day)
        }.count
    }

    private func normalizedDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private func monthDayText(_ date: Date) -> String {
        let comps = calendar.dateComponents([.month, .day], from: date)
        return "\(comps.month ?? 1)月\(comps.day ?? 1)日"
    }

    private func weekdayText(_ date: Date) -> String {
        Self.weekdayText[calendar.component(.weekday, from: date) - 1]
    }

    private static func startOfMonth(for date: Date) -> Date {
        let calendar = SelfDisciplineSchedule.calendar
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }

    private static func recordKeys(from records: [CheckInRecord],
                                   calendar: Calendar) -> Set<CheckInRecordKey> {
        Set(records.map { CheckInRecordKey(day: calendar.startOfDay(for: $0.day), task: $0.task) })
    }

    private static let weekdaySymbols = ["一", "二", "三", "四", "五", "六", "日"]
    private static let weekdayText = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
}

private struct CheckInRecordKey: Hashable {
    let day: Date
    let task: CheckInTask
}

private struct CheckInCalendarDay: Identifiable {
    let date: Date
    let isInVisibleMonth: Bool

    var id: Date { date }
}

/// 月历单元：日历优先——日期数字居中为主角，外圈细环按当天打卡完成度填充，
/// 全勤当天填成实心绿盘；今天 / 选中用外圈细圆标注，不挤压内容。
private struct CheckInMonthDayCell: View {
    let date: Date
    let isInVisibleMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let states: [CheckInTask: Bool]
    let dayNumber: Int
    let action: () -> Void

    /// 进度环尺寸与线宽。
    private let ringSize: CGFloat = 34
    private let lineWidth: CGFloat = 3

    private var total: Int { CheckInTask.allCases.count }
    private var completedCount: Int {
        CheckInTask.allCases.filter { states[$0] == true }.count
    }
    private var isFull: Bool { completedCount == total }
    private var progress: Double {
        total == 0 ? 0 : Double(completedCount) / Double(total)
    }

    private var numberColor: Color {
        if isFull { return .white }
        return completedCount == 0 ? .textMuted : .textPrimary
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                selectionRing
                completionRing
                Text("\(dayNumber)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(numberColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .opacity(isInVisibleMonth ? 1 : 0.34)
        }
        .buttonStyle(.plain)
    }

    /// 今天 / 选中：套在完成度环外的一圈细圆，不改变数字居中。
    @ViewBuilder private var selectionRing: some View {
        if isSelected {
            Circle()
                .stroke(Color.brandBlue.opacity(0.5), lineWidth: 2)
                .frame(width: ringSize + 8, height: ringSize + 8)
        } else if isToday {
            Circle()
                .stroke(Color.brandBlue.opacity(0.28), lineWidth: 1.5)
                .frame(width: ringSize + 8, height: ringSize + 8)
        }
    }

    /// 完成度环：全勤填实心绿盘，否则灰底环上按完成比例描绿弧。
    @ViewBuilder private var completionRing: some View {
        if isFull {
            Circle()
                .fill(Color.successGreen)
                .frame(width: ringSize, height: ringSize)
        } else {
            ZStack {
                Circle()
                    .stroke(Color.textMuted.opacity(0.20), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.successGreen,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: ringSize, height: ringSize)
        }
    }
}

private struct CheckInEditorRow: View {
    let task: CheckInTask
    var detailText: String?
    @Binding var isChecked: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(task.tint)
                .frame(width: 11, height: 11)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.textPrimary)
                Text(detailText ?? task.windowText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            Toggle("", isOn: $isChecked)
                .labelsHidden()
                .tint(task.tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 54)
        .background(Color.appBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.hairline, lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack { SelfDisciplineView() }
        .environmentObject(AppState(repository: MockHealthRepository()))
}
