// ExerciseChart.swift
// 月度消耗柱状图：每月运动消耗总量（千卡），可横向滑动。

import Charts
import SwiftUI

struct ExerciseChart: View {
    let samples: [ExerciseSample]
    /// 柱状配色：随口径变化（活动橙 / 运动绿）。
    var barColor: Color = .exerciseOrange
    /// 可视窗口左沿（最早可见月份起始日）；随手势更新、支持回溯 24 个月。
    @Binding var scrollPosition: Date

    /// 默认同屏月份数：当前月 + 向前 4 个月。
    static let visibleMonths = 5
    /// 柱状统一到顶高度（千卡）：所有月份共用同一纵向标尺。
    private let yTop: Double = 30_000

    /// 可视窗口宽度（秒）：约 `visibleMonths` 个月，保证当前月与前几月同屏。
    private var visibleSeconds: TimeInterval { Double(Self.visibleMonths) * 30.4 * 86_400 }

    var body: some View {
        Chart(samples) { sample in
            BarMark(
                x: .value("月份", sample.month, unit: .month),
                y: .value("千卡", sample.kcal)
            )
            .foregroundStyle(barColor)
            .cornerRadius(5)
        }
        .chartYScale(domain: 0...yTop)
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: visibleSeconds)
        .chartScrollPosition(x: $scrollPosition)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 10_000, 20_000, 30_000]) { value in
                AxisGridLine().foregroundStyle(Color.hairline)
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(axisValue(number))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.textMuted)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(monthLabel(for: date))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.textMuted)
                    }
                }
            }
        }
        .accessibilityLabel("月度运动消耗")
    }

    private func axisValue(_ value: Double) -> String {
        value >= 1_000 ? String(format: "%.0fk", value / 1_000) : String(format: "%.0f", value)
    }

    /// 横轴月份标签：每年 1 月标出年份，便于跨年回溯定位。
    private func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = Calendar.current.component(.month, from: date) == 1 ? "yy年M月" : "M月"
        return formatter.string(from: date)
    }
}

/// 月度消耗口径：活动（活动消耗总量）/ 运动（按次运动消耗总量）。默认「活动」。
enum ExerciseMetric: String, CaseIterable, Identifiable {
    case activity
    case workout

    var id: String { rawValue }

    var label: String {
        switch self {
        case .activity: return "活动"
        case .workout:  return "运动"
        }
    }

    /// 柱状 / 图例配色：活动沿用运动橙，运动用绿。
    var color: Color {
        switch self {
        case .activity: return .exerciseOrange
        case .workout:  return .successGreen
        }
    }

    /// 图例文案。
    var legendTitle: String {
        switch self {
        case .activity: return "每月活动消耗"
        case .workout:  return "每月运动消耗"
        }
    }
}

// MARK: - 运动消耗趋势图（顶部趋势卡）

/// 运动页时间范围：周 / 月 / 6 个月。决定取景窗口与图表呈现方式（与睡眠页同构）。
enum ExerciseRange: String, CaseIterable, Identifiable {
    case week
    case month
    case sixMonths

    var id: String { rawValue }

    var label: String {
        switch self {
        case .week:      return "周"
        case .month:     return "月"
        case .sixMonths: return "6 个月"
        }
    }

    /// 可视窗口两端各预留的空白（秒）：让首尾日期刻度与边缘柱有余量、不被裁切。
    var edgePaddingSeconds: TimeInterval {
        switch self {
        case .week:      return 0.5 * 86_400
        case .month:     return 0.65 * 86_400
        case .sixMonths: return 3.5 * 86_400
        }
    }

    /// 可视窗口宽度（秒）。`nil` 表示不分页，一次展示全部（6 个月周均）。
    var visibleDomainSeconds: TimeInterval? {
        switch self {
        case .week:      return 6 * 86_400 + 2 * edgePaddingSeconds
        case .month:     return 29 * 86_400 + 2 * edgePaddingSeconds
        case .sixMonths: return nil
        }
    }

    /// 6 个月以「周平均每日消耗」折线呈现；周 / 月为日级折线。
    var isWeeklyAverage: Bool { self == .sixMonths }

    /// 日均统计窗口的天数（周 7 / 月 30 / 6 个月 180）。
    var windowDayCount: Int {
        switch self {
        case .week:      return 7
        case .month:     return 30
        case .sixMonths: return 180
        }
    }

    /// 日均卡副标题用的窗口短描述。
    var windowLabel: String {
        switch self {
        case .week:      return "近 7 天"
        case .month:     return "近 30 天"
        case .sixMonths: return "近 6 个月"
        }
    }
}

/// 供统一趋势卡的时间过滤按钮复用。
extension ExerciseRange: TrendRange {}

/// 活动消耗趋势图（平滑折线）：
///   · 周 / 月 —— 每日「活动消耗」折线，固定窗口横向滑动；
///   · 6 个月 —— 每周平均每日消耗折线趋势。
/// 叠加事件：时间段色带、单日事件菱形，点选后常驻显示详情（与体重 / 睡眠趋势图一致）。
struct ExerciseTrendChart: View {
    /// 周 / 月数据源（日级活动消耗，千卡）。
    let dailySamples: [DailyMetric]
    /// 6 个月数据源（每点为一周的平均每日消耗，千卡）。
    let weeklyAverages: [DailyMetric]
    let events: [HealthEvent]
    let showsEvents: Bool
    let range: ExerciseRange
    /// 可视窗口前沿；随手势更新，并驱动外部事件图例过滤。
    @Binding var scrollPosition: Date
    /// 在图上点选的事件（点击事件区域命中）。
    @Binding var selectedEvent: HealthEvent?

    @State private var selectedDate: Date?

    /// 当前呈现所用的数据点（周 / 月 = 日级；6 个月 = 周均），按日期升序。
    private var points: [DailyMetric] {
        (range.isWeeklyAverage ? weeklyAverages : dailySamples).sorted { $0.date < $1.date }
    }

    var body: some View {
        let domain = yDomain
        return scrollable(
            Chart {
                if showsEvents, !range.isWeeklyAverage {
                    ForEach(visibleEvents.filter(\.isPeriod)) { event in
                        RectangleMark(
                            xStart: .value("事件开始", event.startDate),
                            xEnd: .value("事件结束", event.endDate ?? event.startDate),
                            yStart: .value("下界", domain.lowerBound),
                            yEnd: .value("上界", domain.upperBound)
                        )
                        .foregroundStyle(event.type.color.opacity(0.11))

                        RuleMark(x: .value("事件开始边界", event.startDate))
                            .foregroundStyle(event.type.color.opacity(0.55))
                            .lineStyle(eventBoundaryStyle)

                        if let endDate = event.endDate {
                            RuleMark(x: .value("事件结束边界", endDate))
                                .foregroundStyle(event.type.color.opacity(0.55))
                                .lineStyle(eventBoundaryStyle)
                        }
                    }
                }

                ForEach(points) { point in
                    AreaMark(
                        x: .value("日期", point.date),
                        yStart: .value("基线", domain.lowerBound),
                        yEnd: .value("消耗", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [.exerciseOrange.opacity(0.24), .exerciseOrange.opacity(0.01)],
                                       startPoint: .top,
                                       endPoint: .bottom)
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("日期", point.date),
                        y: .value("消耗", point.value)
                    )
                    .foregroundStyle(Color.exerciseOrange)
                    .lineStyle(StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }

                if let last = points.last {
                    PointMark(x: .value("日期", last.date), y: .value("消耗", last.value))
                        .foregroundStyle(Color.exerciseOrange)
                        .symbolSize(55)
                }

                if showsEvents {
                    ForEach(markerEvents) { event in
                        let markerDate = eventMarkerDate(event)
                        PointMark(
                            x: .value("事件日期", markerDate),
                            y: .value("事件位置", valueOnTrend(at: markerDate))
                        )
                        .foregroundStyle(event.type.color)
                        .symbol { EventMark(color: event.type.color) }
                    }
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartXScale(domain: xDomain, range: .plotDimension(padding: 0))
            .chartYScale(domain: domain, range: .plotDimension(padding: 0))
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(Color.hairline)
                    AxisValueLabel {
                        if let kcal = value.as(Double.self) {
                            Text(axisValue(kcal))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.textMuted)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: axisStride) { value in
                    AxisGridLine().foregroundStyle(Color.hairline)
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(axisLabel(for: date))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.textMuted)
                        }
                    }
                }
            }
            .accessibilityLabel(range.isWeeklyAverage ? "每周平均运动消耗趋势" : "每日运动消耗趋势")
        )
        .onChange(of: selectedDate) { _, newDate in
            // 命中事件即选中并常驻；手势结束或点空白都不清空，只在关闭按钮 / 关掉开关时隐藏。
            guard showsEvents, let date = newDate, let hit = eventHit(at: date) else { return }
            selectedEvent = hit
        }
    }

    /// 仅在分页（周 / 月）时启用横向滚动与固定可视窗口；6 个月一次展示完整周均。
    @ViewBuilder
    private func scrollable(_ content: some View) -> some View {
        if let seconds = range.visibleDomainSeconds {
            content
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: seconds)
                .chartScrollPosition(x: $scrollPosition)
        } else {
            content
        }
    }

    // MARK: - 坐标域

    /// 绘图横轴域：数据两端各外扩 edgePadding，避免首尾刻度与边缘柱被裁切。
    private var xDomain: ClosedRange<Date> {
        let dates = points.map(\.date)
        let first = dates.first ?? Date()
        let last = dates.last ?? first
        let pad = range.edgePaddingSeconds
        return first.addingTimeInterval(-pad)...last.addingTimeInterval(pad)
    }

    /// 当前可视窗口区间；6 个月（不分页）覆盖整段周均数据。
    private var visibleWindow: ClosedRange<Date> {
        guard let seconds = range.visibleDomainSeconds else {
            let dates = points.map(\.date)
            let first = dates.first ?? Date()
            return first...(dates.last ?? first)
        }
        return scrollPosition...scrollPosition.addingTimeInterval(seconds)
    }

    /// Y 轴自适应当前窗口内的样本（仿 Apple 健康，滑动时纵向重新取景）。
    private var yDomain: ClosedRange<Double> {
        let window = visibleWindow
        let windowPoints = points.filter { window.contains($0.date) }
        let base = windowPoints.isEmpty ? points : windowPoints
        let values = base.map(\.value)
        let minimum = values.min() ?? 0
        let maximum = values.max() ?? 1
        let padding = max((maximum - minimum) * 0.18, 20)
        return max(0, minimum - padding)...(maximum + padding)
    }

    /// 在日期两侧的趋势样本间线性插值，让事件菱形贴近折线且不改变横坐标。
    private func valueOnTrend(at date: Date) -> Double {
        guard let first = points.first, let last = points.last else { return yDomain.upperBound }
        if date <= first.date { return first.value }
        if date >= last.date { return last.value }
        guard let upperIndex = points.firstIndex(where: { $0.date >= date }), upperIndex > 0 else {
            return first.value
        }
        let lower = points[upperIndex - 1]
        let upper = points[upperIndex]
        let span = upper.date.timeIntervalSince(lower.date)
        guard span > 0 else { return upper.value }
        let progress = date.timeIntervalSince(lower.date) / span
        return lower.value + (upper.value - lower.value) * progress
    }

    // MARK: - 事件叠加

    private var visibleEvents: [HealthEvent] {
        guard let first = points.first?.date, let last = points.last?.date else { return [] }
        return events.filter { event in
            guard event.type.isExerciseRelated else { return false }
            let end = event.endDate ?? event.startDate
            return event.startDate <= last && end >= first
        }
    }

    /// 6 个月把时间段事件压缩成单点；周 / 月仅单日事件用菱形，时间段事件走色带。
    private var markerEvents: [HealthEvent] {
        visibleEvents.filter { range.isWeeklyAverage || !$0.isPeriod }
    }

    private var eventBoundaryStyle: StrokeStyle {
        StrokeStyle(lineWidth: 1.5, dash: [4, 3])
    }

    /// 时间段事件以中点作为代表日期，避免多条事件吸附到同一点后重叠。
    private func eventMarkerDate(_ event: HealthEvent) -> Date {
        let end = event.endDate ?? event.startDate
        return event.startDate.addingTimeInterval(end.timeIntervalSince(event.startDate) / 2)
    }

    /// 把点选日期映射到事件：优先命中时间段色带，其次就近命中单日 / 聚合事件。
    private func eventHit(at date: Date) -> HealthEvent? {
        if !range.isWeeklyAverage, let period = visibleEvents.first(where: { event in
            guard let end = event.endDate else { return false }
            return date >= event.startDate && date <= end
        }) {
            return period
        }
        let span = range.visibleDomainSeconds
            ?? visibleWindow.upperBound.timeIntervalSince(visibleWindow.lowerBound)
        let tolerance = span * (range.isWeeklyAverage ? 0.04 : 0.12)
        let nearest = markerEvents.min {
            abs(eventMarkerDate($0).timeIntervalSince(date)) < abs(eventMarkerDate($1).timeIntervalSince(date))
        }
        if let nearest, abs(eventMarkerDate(nearest).timeIntervalSince(date)) <= tolerance {
            return nearest
        }
        return nil
    }

    // MARK: - 坐标轴

    private var axisStride: AxisMarkValues {
        switch range {
        case .week:      return .stride(by: .day)
        case .month:     return .stride(by: .day, count: 7)
        case .sixMonths: return .stride(by: .month)
        }
    }

    private func axisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        switch range {
        case .week:      formatter.dateFormat = "EEE"   // 周一…周日
        case .month:     formatter.dateFormat = "d日"
        case .sixMonths: formatter.dateFormat = "M月"
        }
        return formatter.string(from: date)
    }

    private func axisValue(_ value: Double) -> String {
        value >= 1_000 ? String(format: "%.1fk", value / 1_000) : String(format: "%.0f", value)
    }
}
