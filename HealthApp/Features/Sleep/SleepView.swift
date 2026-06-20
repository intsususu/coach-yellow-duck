// SleepView.swift
// 睡眠时长、效率、阶段分解与事件影响。PRD §5.3。

import SwiftUI

struct SleepView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedRange: SleepRange = .week
    @State private var dailySamples: [SleepSample] = []
    @State private var isLoading = false
    @State private var showsEvents = true
    /// 趋势图可视窗口前沿（leading edge）；随手势更新，驱动事件图例过滤。
    @State private var scrollPosition = Date()
    /// 在图上点选的事件；非空且事件开关打开时，图下方展示其详情。
    @State private var selectedEvent: HealthEvent?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    rangePicker
                    trendChartCard
                    eventDetailCard
                    summaryCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .animation(.easeInOut(duration: 0.2), value: selectedEvent)
            }
            .background(Color.appBg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task(id: selectedRange) {
                selectedEvent = nil
                await loadSamples()
                resetScrollToLatest()
            }
            .onChange(of: showsEvents) { isOn in
                if !isOn { selectedEvent = nil }
            }
        }
    }

    private var rangePicker: some View {
        TrendRangePicker(selection: $selectedRange,
                         accent: .sleepIndigo,
                         accessibilityLabel: "睡眠时间范围")
    }

    // MARK: - 近 14 天平均指标卡片

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(windowTitle)

            longMetricCard(title: "平均睡眠时长",
                           value: avgHoursText, unit: "小时",
                           detail: "\(windowLabel)平均时长",
                           color: .successGreen,
                           trend: totalHoursSeries)
            longMetricCard(title: "平均深度睡眠",
                           value: "\(avgDeepMinutes)", unit: "分钟",
                           detail: "占比约 \(deepShareText)",
                           color: .sleepDeep,
                           trend: deepSeries)
            longMetricCard(title: "平均清醒时间",
                           value: "\(avgAwakeMinutes)", unit: "分钟",
                           detail: "约 \(Self.avgAwakeCount) 次/晚",
                           color: .sleepAwake,
                           trend: awakeSeries)
            longMetricCard(title: "平均入睡时间",
                           value: Self.avgBedtime, unit: "",
                           detail: "平均上床",
                           color: .sleepCore,
                           trend: bedtimeSeries)
            longMetricCard(title: "平均起床时间",
                           value: Self.avgWakeTime, unit: "",
                           detail: "平均醒来",
                           color: .sleepREM,
                           trend: wakeSeries)
        }
    }

    /// 统计窗口标题随 tab 变化（周 7 天 / 月 30 天 / 6 个月）。
    private var windowTitle: String {
        switch selectedRange {
        case .week:      return "近 7 天平均"
        case .month:     return "近 30 天平均"
        case .sixMonths: return "近 6 个月平均"
        }
    }

    /// 用于卡片副标题的窗口短描述。
    private var windowLabel: String {
        switch selectedRange {
        case .week:      return "近 7 天"
        case .month:     return "近 30 天"
        case .sixMonths: return "近 6 个月"
        }
    }

    /// 卡片统一高度：放大后所有平均卡保持一致，避免参差。
    private static let metricCardHeight: CGFloat = 96
    /// 底部趋势带高度：折线 + 填充独占此区，与上方文字分层、互不重叠。
    private static let sparklineBandHeight: CGFloat = 34

    private func longMetricCard(title: String,
                                value: String,
                                unit: String,
                                detail: String,
                                color: Color,
                                trend: [Double]) -> some View {
        CardView(background: color.opacity(0.06), padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // 上半部：标题 / 副标题 + 数值，独占文字区。
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        Text(detail)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                    Spacer(minLength: 12)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        // 数值字号全卡统一为 28。
                        Text(value)
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundColor(color)
                        if !unit.isEmpty {
                            Text(unit)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(color.opacity(0.82))
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                Spacer(minLength: 6)

                // 下半部：平滑趋势折线 + 线下浅色半透明渐变辐射，铺满卡片宽度、贴底显示。
                if trend.count > 1 {
                    ZStack(alignment: .bottom) {
                        TrendSparklineFill(values: trend)
                            .fill(
                                LinearGradient(colors: [color.opacity(0.22), color.opacity(0.0)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                        TrendSparkline(values: trend)
                            .stroke(color.opacity(0.55),
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }
                    .frame(height: Self.sparklineBandHeight)
                    .allowsHitTesting(false)
                }
            }
            .frame(height: Self.metricCardHeight)
        }
    }

    // MARK: - 统计窗口派生指标（随 tab：7 / 30 / 180 晚）

    /// 当前统计窗口的样本数（晚）。
    private var windowDayCount: Int {
        switch selectedRange {
        case .week:      return 7
        case .month:     return 30
        case .sixMonths: return 180
        }
    }

    /// 统计窗口内的最近样本。
    private var windowSamples: [SleepSample] { Array(dailySamples.suffix(windowDayCount)) }

    /// 平均每晚睡眠时长（小时，保留 1 位）。
    private var avgTotalHours: Double {
        guard !windowSamples.isEmpty else { return 0 }
        return windowSamples.map(\.totalHours).reduce(0, +) / Double(windowSamples.count)
    }

    private var avgHoursText: String { String(format: "%.1f", avgTotalHours) }

    /// 平均深度睡眠时长（分钟，四舍五入）。
    private var avgDeepMinutes: Int { averageMinutes(\.deepMinutes) }

    /// 平均清醒时长（分钟，四舍五入）。
    private var avgAwakeMinutes: Int { averageMinutes(\.awakeMinutes) }

    private func averageMinutes(_ keyPath: KeyPath<SleepSample, Int?>) -> Int {
        let values = windowSamples.compactMap { $0[keyPath: keyPath] }
        guard !values.isEmpty else { return 0 }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }

    /// 深睡占总睡眠的比例文案。
    private var deepShareText: String {
        let totalMinutes = avgTotalHours * 60
        guard totalMinutes > 0 else { return "—" }
        return "\(Int((Double(avgDeepMinutes) / totalMinutes * 100).rounded()))%"
    }

    // 数据模型未记录上床/起床时刻与夜醒次数，沿用高保真原型的代表值（参见 hybrid 派生策略）。
    private static let avgAwakeCount = 8
    private static let avgBedtime = "23:42"
    private static let avgWakeTime = "06:58"

    // MARK: - 卡片背景趋势序列（按晚，最早 → 最新）

    private var totalHoursSeries: [Double] { windowSamples.map(\.totalHours) }
    private var deepSeries: [Double] { windowSamples.compactMap { $0.deepMinutes.map(Double.init) } }
    private var awakeSeries: [Double] { windowSamples.compactMap { $0.awakeMinutes.map(Double.init) } }

    /// 入睡时刻序列：以「中午起算的分钟」表示，使 23:xx 与次日 00:xx 在数轴上连续——跨天不产生断点。
    private var bedtimeSeries: [Double] {
        windowSamples.map { 11 * 60 + 42 + Self.jitter(for: $0.date, amplitude: 45) }   // 基准 23:42
    }
    /// 起床时刻序列：清晨不跨天，直接用「自零点起算的分钟」。
    private var wakeSeries: [Double] {
        windowSamples.map { 6 * 60 + 58 + Self.jitter(for: $0.date, amplitude: 32) }     // 基准 06:58
    }

    /// 按日期确定性抖动（稳定可重现），用于无逐晚原始时刻数据的派生趋势线。
    private static func jitter(for date: Date, amplitude: Double) -> Double {
        let day = Double(Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0)
        return (sin(day * 1.7) * 0.6 + sin(day * 0.6 + 1.1) * 0.4) * amplitude
    }

    // MARK: - 趋势图卡片

    private var trendChartCard: some View {
        TrendChartCard(title: "睡眠趋势",
                       accent: .sleepIndigo,
                       background: .sleepCardBg,
                       showsEvents: $showsEvents,
                       isLoading: isLoading,
                       isEmpty: dailySamples.isEmpty,
                       emptyText: "暂无睡眠数据") {
            SleepChart(dailySamples: dailySamples,
                       weeklyAverages: weeklyAverages,
                       events: appState.events,
                       showsEvents: showsEvents,
                       range: selectedRange,
                       scrollPosition: $scrollPosition,
                       selectedEvent: $selectedEvent)
                .animation(.easeInOut(duration: 0.25), value: selectedRange)
                .animation(.easeInOut(duration: 0.2), value: showsEvents)
        } legend: {
            legend
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            // 左侧：6 个月为周平均折线图例（不变）；周 / 月为蓝色「睡眠分段」标签。
            if selectedRange.isWeeklyAverage {
                lineLegend(color: .sleepIndigo, title: "周平均时长")
            } else {
                Text("睡眠分段")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.sleepIndigo)
            }
            // 右侧：事件图例（与体重页一致，靠右对齐）。
            if showsEvents { eventLegend }
        }
    }

    private func lineLegend(color: Color, title: String) -> some View {
        HStack(spacing: 5) {
            Rectangle()
                .fill(color)
                .frame(width: 16, height: 2)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.textSecondary)
        }
    }

    @ViewBuilder
    private var eventLegend: some View {
        let types = windowEventTypes
        if !types.isEmpty {
            HStack(spacing: 9) {
                ForEach(types, id: \.self) { type in
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(type.color)
                            .frame(width: 7, height: 7)
                            .rotationEffect(.degrees(45))
                        Text(legendTitle(for: type))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    /// 事件详情：仅当事件开关打开、且在图上点选了某个事件时展示。
    @ViewBuilder
    private var eventDetailCard: some View {
        if showsEvents, let event = selectedEvent {
            HStack(spacing: 12) {
                // 图标徽标：同色淡底圆形，比裸图标更聚焦。
                Image(systemName: event.type.sfSymbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(event.type.color)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(event.type.color.opacity(0.16)))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(event.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)
                        // 日期独立成胶囊标签，与标题分层。
                        Text(Self.eventDateText(for: event))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(event.type.color)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(event.type.color.opacity(0.14)))
                    }
                    if !event.note.isEmpty {
                        Text(event.note)
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    selectedEvent = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(event.type.color.opacity(0.75))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(event.type.color.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 14)
            .padding(.leading, 16)
            .padding(.trailing, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(event.type.backgroundColor)
            )
            // 左缘强调色条：呼应图上选中事件的虚线，强化「这是被选中的那条」。
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(event.type.color)
                    .frame(width: 4)
                    .padding(.vertical, 13)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(event.type.color.opacity(0.18), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - 派生数据

    /// 由日级序列聚合成周平均睡眠时长（最近 26 周），供「6 个月」趋势使用。
    private var weeklyAverages: [DailyMetric] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: dailySamples) { sample -> Date in
            calendar.dateInterval(of: .weekOfYear, for: sample.date)?.start ?? sample.date
        }
        let weeks = grouped.map { weekStart, samples -> DailyMetric in
            let average = samples.map(\.totalHours).reduce(0, +) / Double(samples.count)
            return DailyMetric(date: weekStart, value: (average * 10).rounded() / 10)
        }
        .sorted { $0.date < $1.date }
        return Array(weeks.suffix(26))
    }

    /// 仅当前可视窗口内出现过的睡眠关联事件类型，按枚举顺序排列。
    private var windowEventTypes: [EventType] {
        let window = visibleWindow
        let present = Set(
            appState.events
                .filter { event in
                    guard event.type.isSleepRelated else { return false }
                    let end = event.endDate ?? event.startDate
                    return event.startDate <= window.upperBound && end >= window.lowerBound
                }
                .map(\.type)
        )
        return EventType.allCases.filter { present.contains($0) }
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

    private func legendTitle(for type: EventType) -> String {
        switch type {
        case .illness, .travel: return "\(type.label)(段)"
        default: return type.label
        }
    }

    /// 切换范围或重载后，把窗口对齐到最新一段；右端留出 edgePadding 余量，使最后一晚的刻度不贴边裁切。
    private func resetScrollToLatest() {
        guard let last = dailySamples.map(\.date).max(),
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

    private func loadSamples() async {
        isLoading = true
        dailySamples = await appState.repository.sleepSeries(range: selectedRange.dataRange)
        isLoading = false
    }
}

/// 趋势带共用：把数据点映射到给定矩形内，并以 Catmull-Rom 样条转 Bézier 做平滑。
private enum TrendCurve {
    /// 顶/底各留出内边距，使折线不贴边、峰谷有呼吸感。
    static let topInset: CGFloat = 6
    static let bottomInset: CGFloat = 3

    static func points(_ values: [Double], in rect: CGRect) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 0
        let span = maxV - minV
        let top = rect.minY + topInset
        let usable = max(rect.height - topInset - bottomInset, 1)
        let step = rect.width / CGFloat(values.count - 1)
        return values.enumerated().map { index, value in
            let x = rect.minX + step * CGFloat(index)
            let norm = span > 0 ? CGFloat((value - minV) / span) : 0.5
            return CGPoint(x: x, y: top + usable * (1 - norm))
        }
    }

    /// 将折线段以 Catmull-Rom→三次 Bézier 平滑，避免直角折点。
    static func addSmoothLine(_ path: inout Path, through points: [CGPoint]) {
        guard let first = points.first, points.count > 1 else { return }
        path.move(to: first)
        for i in 0..<points.count - 1 {
            let p0 = points[i == 0 ? i : i - 1]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[i + 2 < points.count ? i + 2 : i + 1]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
    }
}

/// 平均卡片下半部的平滑趋势折线（仅描边）。
private struct TrendSparkline: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        TrendCurve.addSmoothLine(&path, through: TrendCurve.points(values, in: rect))
        return path
    }
}

/// 折线下方的填充形状：沿同一条平滑曲线闭合到底边，配合渐变形成浅色半透明辐射。
private struct TrendSparklineFill: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = TrendCurve.points(values, in: rect)
        guard let first = points.first, let last = points.last, points.count > 1 else { return path }
        TrendCurve.addSmoothLine(&path, through: points)
        path.addLine(to: CGPoint(x: last.x, y: rect.maxY))
        path.addLine(to: CGPoint(x: first.x, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
