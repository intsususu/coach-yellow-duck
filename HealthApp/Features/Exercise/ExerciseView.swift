// ExerciseView.swift
// 运动消耗、时长、心率、类型与事件影响。PRD §5.4。

import SwiftUI

struct ExerciseView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ExerciseViewModel()
    /// 顶部周期：周 / 月 / 6 个月，驱动运动消耗趋势卡。默认「月」，30 天窗口可一眼看出停训影响。
    @State private var selectedRange: ExerciseRange = .month
    /// 是否叠加事件：全局开关，由首页顶部控制，各趋势页共用。
    private var showsEvents: Bool { appState.showsEvents }
    /// 趋势图可视窗口前沿；随手势更新，驱动事件图例过滤。
    @State private var scrollPosition = Date()
    /// 在图上点选的事件；非空且事件开关打开时，图下方展示其详情。
    @State private var selectedEvent: HealthEvent?
    /// 点击图例时选中的基础类型；与图上单条事件选中互斥。
    @State private var selectedLegendType: EventType?

    /// 月度消耗口径：活动 / 运动，默认「运动」。
    @State private var monthlyMetric: ExerciseMetric = .workout
    /// 月度消耗图可视窗口左沿；驱动横向回溯定位。
    @State private var monthlyScroll = Date()

    private var exerciseDaily: [DailyMetric] { viewModel.exerciseDaily }
    private var basalDaily: [DailyMetric] { viewModel.basalDaily }
    private var samples: [ExerciseSample] { viewModel.monthlySamples }
    private var workouts: [WorkoutSession] { viewModel.workouts }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    rangePicker
                    trendChartCard
                    eventDetailCard
                    dailyAverageCard
                    statisticsCard
                    metricChartCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .animation(.easeInOut(duration: 0.2), value: selectedEvent)
                .animation(.easeInOut(duration: 0.2), value: selectedLegendType)
            }
            .background(Color.appBg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.loadMonthlyIfNeeded(from: appState.repository)
                resetMonthlyScroll()
            }
            .task {
                selectedEvent = nil
                selectedLegendType = nil
                await viewModel.loadDailyIfNeeded(from: appState.repository)
                resetScrollToLatest()
            }
            .onChange(of: selectedRange) { _ in
                selectedEvent = nil
                selectedLegendType = nil
                resetScrollToLatest()
            }
            .onChange(of: showsEvents) { isOn in
                if !isOn {
                    selectedEvent = nil
                    selectedLegendType = nil
                }
            }
            .onChange(of: selectedEvent) { event in
                if event != nil { selectedLegendType = nil }
            }
            .onChange(of: monthlyMetric) { _ in
                resetMonthlyScroll()
            }
        }
    }

    // MARK: - 周期选择 + 运动消耗趋势卡

    private var rangePicker: some View {
        TrendRangePicker(selection: $selectedRange,
                         accent: .exerciseOrange,
                         accessibilityLabel: "运动时间范围")
    }

    private var trendChartCard: some View {
        TrendChartCard(title: "活动消耗趋势",
                       accent: .exerciseOrange,
                       background: .exerciseCardBg,
                       isLoading: viewModel.isDailyLoading,
                       isEmpty: exerciseDaily.isEmpty,
                       emptyText: "暂无运动数据") {
            ExerciseTrendChart(dailySamples: exerciseDaily,
                               weeklyAverages: weeklyAverages,
                               events: appState.events,
                               showsEvents: showsEvents,
                               range: selectedRange,
                               scrollPosition: $scrollPosition,
                               selectedEvent: $selectedEvent)
                .animation(.easeInOut(duration: 0.25), value: selectedRange)
                .animation(.easeInOut(duration: 0.2), value: showsEvents)
        } legend: {
            trendLegend
        }
    }

    private var trendLegend: some View {
        HStack(spacing: 14) {
            HStack(spacing: 5) {
                Rectangle()
                    .fill(Color.exerciseOrange)
                    .frame(width: 16, height: 2)
                Text(selectedRange.isWeeklyAverage ? "周均消耗" : "每日消耗")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
            if showsEvents { eventLegend }
        }
    }

    @ViewBuilder
    private var eventLegend: some View {
        let types = windowEventTypes
        if !types.isEmpty {
            HStack(spacing: 9) {
                ForEach(types, id: \.self) { type in
                    Button {
                        selectLegendEvent(of: type)
                    } label: {
                        HStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(type.color)
                                .frame(width: 7, height: 7)
                                .rotationEffect(.degrees(45))
                            Text(type.label)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.horizontal, 4)
                        .frame(height: TrendCardSpec.legendHeight)
                        .background(isLegendHighlighted(type) ? type.color.opacity(0.12) : .clear)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(selectedLegendType == type ? "收起\(type.label)事件" : "查看\(type.label)事件")
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - 选中事件详情卡（点图 / 点图例）

    @ViewBuilder
    private var eventDetailCard: some View {
        if showsEvents, let first = detailEvents.first {
            VStack(spacing: 0) {
                HStack {
                    Text(selectedLegendType.map { "\($0.label)事件 · \(detailEvents.count) 条" } ?? "事件详情")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(first.type.color)
                    Spacer()
                    Button { clearEventSelection() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(first.type.color.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 2)

                ForEach(Array(detailEvents.enumerated()), id: \.element.id) { index, event in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: event.type.sfSymbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(event.type.color)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(event.type.color.opacity(0.16)))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(Self.eventDateText(for: event)) · \(event.title)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.textPrimary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            if !event.note.isEmpty {
                                Text(event.note)
                                    .font(.system(size: 12))
                                    .foregroundColor(.textSecondary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)
                    if index < detailEvents.count - 1 {
                        Divider()
                            .background(Color.hairline)
                            .padding(.leading, 48)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(first.type.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(first.type.color.opacity(0.22), lineWidth: 1)
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - 日均消耗卡

    /// 周期与顶部 tab 一致：累加窗口内有数据的每日点求日均活动消耗，
    /// 并叠加静息（基础代谢）得到 Health 中「含静息代谢的总消耗」。不含单独的运动记录。
    private var dailyAverageCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "日均消耗") {
                    Text(visibleRangeLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
                HStack(spacing: 0) {
                    avgStat(title: "活动消耗", value: dailyAvgActive, color: .exerciseOrange)
                    avgStat(title: "总消耗", value: dailyAvgTotal, color: .textPrimary)
                }
                Text("总消耗含静息代谢（基础代谢），未计入单独的运动记录。")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.textMuted)
            }
        }
    }

    private func avgStat(title: String, value: Double, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                // 左侧等宽隐藏单位，抵消右侧「千卡」的宽度，使数字真正居中对齐到标题。
                Text("千卡")
                    .font(.system(size: 10, weight: .medium))
                    .hidden()
                Text(value > 0 ? "\(Int(value.rounded()))" : "--")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(color)
                Text("千卡")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// 当前周期窗口内有数据的每日活动消耗点；跟随趋势图可视窗口（横滑后同步）。
    private var windowActiveSamples: [DailyMetric] {
        let window = visibleWindow
        return exerciseDaily.filter { window.contains($0.date) }
    }

    /// 日均活动消耗：窗口内各点累加 ÷ 有数据的点数。
    private var dailyAvgActive: Double {
        let values = windowActiveSamples.map(\.value)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// 日均总消耗（含静息）：窗口内每日「活动 + 静息」累加 ÷ 点数。
    private var dailyAvgTotal: Double {
        let calendar = Calendar.current
        let basalByDay = Dictionary(basalDaily.map { (calendar.startOfDay(for: $0.date), $0.value) },
                                    uniquingKeysWith: { first, _ in first })
        let totals = windowActiveSamples.map { active in
            active.value + (basalByDay[calendar.startOfDay(for: active.date)] ?? 0)
        }
        guard !totals.isEmpty else { return 0 }
        return totals.reduce(0, +) / Double(totals.count)
    }

    // MARK: - 运动统计卡

    /// 周期与顶部 tab 一致；仅统计窗口内「有运动」的天与次，剔除无运动的天。
    /// 上方 4 项关键指标，下方为时间段分布与类型占比。
    private var statisticsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(title: "运动统计") {
                    Text(visibleRangeLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
                if windowWorkouts.isEmpty {
                    Text("本周期暂无运动记录")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    HStack(alignment: .top, spacing: 0) {
                        workoutStat(title: "日均运动消耗",
                                    value: "\(Int(dailyAvgWorkoutKcal.rounded()))", unit: "千卡")
                        workoutStat(title: "日均运动时长",
                                    value: "\(dailyAvgWorkoutMinutes)", unit: "分钟")
                        workoutStat(title: "平均心率",
                                    value: avgHeartRate > 0 ? "\(Int(avgHeartRate.rounded()))" : "--",
                                    unit: "次/分")
                    }
                    HStack(alignment: .top, spacing: 0) {
                        workoutStat(title: "运动总消耗",
                                    value: String(format: "%.1f", totalWorkoutKcal / 1_000),
                                    unit: "K千卡", valueColor: .textPrimary)
                        workoutDaysStat()
                        workoutStat(title: "运动次数",
                                    value: "\(windowWorkouts.count)", unit: "次",
                                    valueColor: .textPrimary)
                    }
                    Divider().background(Color.hairline)
                    timeBandSection
                    typeProportionSection
                }
            }
        }
    }

    private func workoutStat(title: String, value: String, unit: String,
                             valueColor: Color = .exerciseOrange) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundColor(valueColor)
                Text(unit)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// 运动天数：有运动的天数（绿）/ 周期总天数（黑）。
    private func workoutDaysStat() -> some View {
        VStack(spacing: 5) {
            Text("运动天数")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                (Text("\(exerciseDayCount)").foregroundColor(.successGreen)
                    + Text("/\(selectedRange.windowDayCount)").foregroundColor(.textPrimary))
                    .font(.system(size: 19, weight: .heavy))
                Text("天")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// 周期内主要运动时间段：早 / 中 / 下午 / 晚四格，次数最多者高亮。
    private var timeBandSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("周期内主要运动时间段")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.textPrimary)
            HStack(spacing: 8) {
                ForEach(timeBandStats, id: \.band) { entry in
                    let isTop = entry.band == dominantBand && entry.count > 0
                    VStack(spacing: 5) {
                        Text(entry.band.label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isTop ? .exerciseOrange : .textSecondary)
                        Text(entry.count > 0 ? "\(entry.percent)%" : "—")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(isTop ? .exerciseOrange : .textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.exerciseOrange.opacity(isTop ? 0.12 : 0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    /// 运动类型占比：横向堆叠条 + 自适应换行图例。
    private var typeProportionSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("运动类型占比")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.textPrimary)
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(typeStats, id: \.kind) { entry in
                        Rectangle()
                            .fill(entry.kind.color)
                            .frame(width: geo.size.width * entry.fraction)
                    }
                }
            }
            .frame(height: 10)
            .clipShape(Capsule())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)],
                      alignment: .leading, spacing: 6) {
                ForEach(typeStats, id: \.kind) { entry in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(entry.kind.color)
                            .frame(width: 8, height: 8)
                        Text("\(entry.kind.label) \(entry.percent)%")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    /// 月度消耗：默认展示当前月 + 向前 6 个月，可横向滑动回溯至多 24 个月；柱状统一到顶 30k。
    /// 右上角「活动 / 运动」切换消耗口径，默认「活动」。
    private var metricChartCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("月度消耗")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Picker("消耗口径", selection: $monthlyMetric) {
                        ForEach(ExerciseMetric.allCases) { metric in
                            Text(metric.label).tag(metric)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(monthlyMetric.color)
                    .frame(width: 124)
                    .fixedSize()
                    .accessibilityLabel("月度消耗口径")
                }

                if viewModel.isMonthlyLoading && samples.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    ExerciseChart(samples: monthlySamples,
                                  barColor: monthlyMetric.color,
                                  scrollPosition: $monthlyScroll)
                        .frame(height: 200)
                }

                legend(color: monthlyMetric.color, title: monthlyMetric.legendTitle)
            }
        }
    }

    /// 当前口径下的月度样本：「活动」用活动消耗月序列；「运动」按月聚合按次运动消耗。
    private var monthlySamples: [ExerciseSample] {
        monthlyMetric == .activity ? samples : workoutMonthlySamples
    }

    /// 「运动」口径月度消耗：把所有按次运动记录按自然月聚合求和。
    private var workoutMonthlySamples: [ExerciseSample] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: workouts) { session -> Date in
            calendar.date(from: calendar.dateComponents([.year, .month], from: session.start)) ?? session.start
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月"
        return grouped
            .map { month, sessions in
                ExerciseSample(month: month,
                               label: formatter.string(from: month),
                               kcal: sessions.map(\.kcal).reduce(0, +))
            }
            .sorted { $0.month < $1.month }
    }

    /// 把月度图滑到最新一段：左沿对齐「最新月向前 visibleMonths−1 个月」，当前月落在右端。
    private func resetMonthlyScroll() {
        guard let last = monthlySamples.last?.month else { return }
        let calendar = Calendar.current
        monthlyScroll = calendar.date(byAdding: .month,
                                      value: -(ExerciseChart.visibleMonths - 1),
                                      to: last) ?? last
    }

    private func legend(color: Color, title: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.textSecondary)
        }
    }

    // MARK: - 运动统计派生数据

    /// 当前周期窗口区间：跟随趋势图可视窗口（横滑后同步），而非永远取最新一段。
    private var statsWindow: ClosedRange<Date> {
        visibleWindow
    }

    /// 窗口内全部运动记录（无运动的天自然不出现）。
    private var windowWorkouts: [WorkoutSession] {
        let calendar = Calendar.current
        let window = statsWindow
        return workouts.filter {
            let day = calendar.startOfDay(for: $0.start)
            return day >= window.lowerBound && day <= window.upperBound
        }
    }

    /// 有运动的天数（去重）。
    private var exerciseDayCount: Int {
        let calendar = Calendar.current
        return Set(windowWorkouts.map { calendar.startOfDay(for: $0.start) }).count
    }

    /// 窗口内运动消耗合计（运动总消耗）。
    private var totalWorkoutKcal: Double {
        windowWorkouts.map(\.kcal).reduce(0, +)
    }

    /// 日均运动消耗：窗口内运动消耗合计 ÷ 有运动的天数（剔除无运动天）。
    private var dailyAvgWorkoutKcal: Double {
        guard exerciseDayCount > 0 else { return 0 }
        return totalWorkoutKcal / Double(exerciseDayCount)
    }

    /// 平均心率：窗口内有心率记录的运动求简单平均；无记录则为 0。
    private var avgHeartRate: Double {
        let values = windowWorkouts.compactMap(\.avgHR)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// 日均运动时长（分钟）：窗口内时长合计 ÷ 有运动的天数。
    private var dailyAvgWorkoutMinutes: Int {
        guard exerciseDayCount > 0 else { return 0 }
        let total = windowWorkouts.map(\.minutes).reduce(0, +)
        return Int((Double(total) / Double(exerciseDayCount)).rounded())
    }

    /// 各时间段运动次数与占比。
    private var timeBandStats: [(band: WorkoutTimeBand, count: Int, percent: Int)] {
        let calendar = Calendar.current
        var counts: [WorkoutTimeBand: Int] = [:]
        for workout in windowWorkouts {
            let hour = calendar.component(.hour, from: workout.start)
            counts[WorkoutTimeBand(hour: hour), default: 0] += 1
        }
        let total = max(windowWorkouts.count, 1)
        return WorkoutTimeBand.allCases.map { band in
            let count = counts[band] ?? 0
            return (band, count, Int((Double(count) / Double(total) * 100).rounded()))
        }
    }

    /// 次数最多的时间段（高亮「主要」用）。
    private var dominantBand: WorkoutTimeBand? {
        timeBandStats.max { $0.count < $1.count }?.band
    }

    /// 各运动类型次数、占比与条形占宽，按次数降序，仅含出现过的类型。
    private var typeStats: [(kind: WorkoutKind, count: Int, percent: Int, fraction: Double)] {
        var counts: [WorkoutKind: Int] = [:]
        for workout in windowWorkouts { counts[workout.type, default: 0] += 1 }
        let total = max(windowWorkouts.count, 1)
        let entries = WorkoutKind.allCases.compactMap {
            kind -> (kind: WorkoutKind, count: Int, percent: Int, fraction: Double)? in
            let count = counts[kind] ?? 0
            guard count > 0 else { return nil }
            return (kind, count,
                    Int((Double(count) / Double(total) * 100).rounded()),
                    Double(count) / Double(total))
        }
        return entries.sorted { $0.count > $1.count }
    }

    // MARK: - 派生数据

    /// 由日级序列聚合成每周平均每日消耗（最近 26 周），供「6 个月」趋势使用。
    private var weeklyAverages: [DailyMetric] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: exerciseDaily) { sample -> Date in
            calendar.dateInterval(of: .weekOfYear, for: sample.date)?.start ?? sample.date
        }
        let weeks = grouped.map { weekStart, samples -> DailyMetric in
            let average = samples.map(\.value).reduce(0, +) / Double(samples.count)
            return DailyMetric(date: weekStart, value: average.rounded())
        }
        .sorted { $0.date < $1.date }
        return Array(weeks.suffix(26))
    }

    /// 仅当前可视窗口内出现过的运动关联事件类型，按枚举顺序排列。
    private var windowEventTypes: [EventType] {
        let present = Set(windowEvents.map(\.type))
        return EventType.allCases.filter { present.contains($0) }
    }

    private var windowEvents: [HealthEvent] {
        let window = visibleWindow
        return appState.events.filter { event in
            guard event.type.isExerciseRelated else { return false }
            let end = event.endDate ?? event.startDate
            return event.startDate <= window.upperBound && end >= window.lowerBound
        }
    }

    private func selectLegendEvent(of type: EventType) {
        selectedEvent = nil
        selectedLegendType = selectedLegendType == type ? nil : type
    }

    private func isLegendHighlighted(_ type: EventType) -> Bool {
        selectedLegendType == type || (selectedLegendType == nil && selectedEvent?.type == type)
    }

    private var detailEvents: [HealthEvent] {
        if let selectedLegendType {
            return windowEvents
                .filter { $0.type == selectedLegendType }
                .sorted { $0.startDate > $1.startDate }
        }
        return selectedEvent.map { [$0] } ?? []
    }

    /// 卡片副标题：跟随趋势图可视窗口。周 / 月横滑后显示实际日期区间；6 个月（不分页）保持「近 6 个月」。
    private var visibleRangeLabel: String {
        guard selectedRange.visibleDomainSeconds != nil,
              let first = windowActiveSamples.first?.date,
              let last = windowActiveSamples.last?.date else {
            return selectedRange.windowLabel
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return "\(formatter.string(from: first)) – \(formatter.string(from: last))"
    }

    /// 当前趋势图可视窗口区间。「6 个月」无固定窗口，返回周均序列整段区间。
    private var visibleWindow: ClosedRange<Date> {
        guard let seconds = selectedRange.visibleDomainSeconds else {
            let dates = weeklyAverages.map(\.date)
            let first = dates.first ?? Date()
            return first...(dates.last ?? first)
        }
        return scrollPosition...scrollPosition.addingTimeInterval(seconds)
    }

    private func clearEventSelection() {
        selectedEvent = nil
        selectedLegendType = nil
    }

    /// 切换范围或重载后，把窗口对齐到最新一段；右端留出 edgePadding 余量。
    private func resetScrollToLatest() {
        guard let last = exerciseDaily.map(\.date).max(),
              let seconds = selectedRange.visibleDomainSeconds else { return }
        scrollPosition = last.addingTimeInterval(-(seconds - selectedRange.edgePaddingSeconds))
    }

    private static let eventDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    private static func eventDateText(for event: HealthEvent) -> String {
        let start = eventDateFormatter.string(from: event.startDate)
        guard let endDate = event.endDate else { return start }
        return "\(start)–\(eventDateFormatter.string(from: endDate))"
    }

}
