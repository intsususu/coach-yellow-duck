// WeightChart.swift
// 可复用体重折线图：趋势、单日事件点与时间段色带。
// 仿 Apple 健康：固定宽度的可视窗口（周 7 天 / 月 30 天 / 年 12 月）随手势横向滑动。

import Charts
import SwiftUI

struct WeightChart: View {
    let samples: [WeightSample]
    let events: [HealthEvent]
    let showsEvents: Bool
    let range: TimeRange
    /// 可视窗口前沿（leading edge）。为 nil 时（「全部」）一次展示全部数据，不分页。
    @Binding var scrollPosition: Date
    /// 在图上点选的事件（点击事件区域命中，点空白处清空）。
    @Binding var selectedEvent: HealthEvent?

    /// Charts X 轴点选返回的连续日期，再映射到具体事件。
    @State private var selectedDate: Date?

    private var sortedSamples: [WeightSample] {
        samples.sorted { $0.date < $1.date }
    }

    /// 当前可视窗口区间；`visibleDomainSeconds` 为 nil（「全部」）时覆盖整段数据。
    private var visibleWindow: ClosedRange<Date> {
        guard let seconds = range.visibleDomainSeconds else {
            let first = sortedSamples.first?.date ?? Date()
            let last = sortedSamples.last?.date ?? Date()
            return first...max(first, last)
        }
        return scrollPosition...scrollPosition.addingTimeInterval(seconds)
    }

    /// 绘图域右侧留白：让最后一个圆点离开裁剪边界（与 WeightView 的滚动对齐保持同一比例）。
    private var trailingPadSeconds: Double {
        if let seconds = range.visibleDomainSeconds { return seconds * WeightChart.trailingPadFactor }
        let first = sortedSamples.first?.date ?? Date()
        let last = sortedSamples.last?.date ?? Date()
        return max(last.timeIntervalSince(first) * WeightChart.trailingPadFactor, 86_400)
    }

    static let trailingPadFactor = 0.04

    /// 可视跨度达 6 个月时，时间段事件也压缩成聚合趋势线上的点。
    private var usesCondensedEventMarkers: Bool {
        let sixMonths = 180.0 * 86_400
        if let seconds = range.visibleDomainSeconds { return seconds >= sixMonths }
        return visibleWindow.upperBound.timeIntervalSince(visibleWindow.lowerBound) >= sixMonths
    }

    private var visibleEvents: [HealthEvent] {
        guard let first = sortedSamples.first?.date, let last = sortedSamples.last?.date else { return [] }
        return events.filter { event in
            let eventEnd = event.endDate ?? event.startDate
            return event.startDate <= last && eventEnd >= first
        }
    }

    /// Y 轴自适应当前窗口内的样本（仿 Apple 健康，滑动时纵向重新取景）。
    private var yDomain: ClosedRange<Double> {
        let window = visibleWindow
        let windowSamples = sortedSamples.filter { window.contains($0.date) }
        let base = windowSamples.isEmpty ? sortedSamples : windowSamples
        let values = base.map(\.kg)
        let minimum = values.min() ?? 0
        let maximum = values.max() ?? 1
        let padding = max((maximum - minimum) * 0.18, 1.0)
        return (minimum - padding)...(maximum + padding)
    }

    var body: some View {
        let domain = yDomain
        return scrollable(
            Chart {
                if showsEvents, !usesCondensedEventMarkers {
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

                ForEach(sortedSamples) { sample in
                    AreaMark(
                        x: .value("日期", sample.date),
                        yStart: .value("基线", domain.lowerBound),
                        yEnd: .value("体重", sample.kg)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [.weightGreen.opacity(0.24), .weightGreen.opacity(0.01)],
                                       startPoint: .top,
                                       endPoint: .bottom)
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("日期", sample.date),
                        y: .value("体重", sample.kg)
                    )
                    .foregroundStyle(Color.weightGreen)
                    .lineStyle(StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }

                if let last = sortedSamples.last {
                    PointMark(x: .value("日期", last.date), y: .value("体重", last.kg))
                        .foregroundStyle(Color.weightGreen)
                        .symbolSize(55)

                    // 末尾留白锚点：把绘图域向右撑出一点，避免最后一个圆点贴边被裁掉半个。
                    PointMark(x: .value("末尾留白", last.date.addingTimeInterval(trailingPadSeconds)),
                              y: .value("体重", last.kg))
                        .foregroundStyle(.clear)
                        .symbolSize(0)
                }

                if showsEvents {
                    ForEach(markerEvents) { event in
                        let markerDate = eventMarkerDate(event)
                        PointMark(
                            x: .value("事件日期", markerDate),
                            y: .value("事件体重", weightOnTrend(at: markerDate))
                        )
                        .foregroundStyle(event.type.color)
                        .symbol { EventMark(color: event.type.color) }
                    }
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartYScale(domain: domain)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(Color.hairline)
                    AxisValueLabel {
                        if let weight = value.as(Double.self) {
                            Text(String(format: "%.0f", weight))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.textMuted)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: axisStride) { value in
                    AxisGridLine().foregroundStyle(Color.hairline)
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(axisLabel(for: date))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.textMuted)
                        }
                    }
                }
            }
            .accessibilityLabel("体重趋势图")
        )
        .onChange(of: selectedDate) { _, newDate in
            // 命中折线上的事件即选中并常驻显示详情；手势结束(newDate=nil)或点空白都不清空，
            // 详情只在点击关闭按钮或关掉「事件」开关时才隐藏。
            guard showsEvents, let date = newDate, let hit = eventHit(at: date) else { return }
            selectedEvent = hit
        }
    }

    private var eventBoundaryStyle: StrokeStyle {
        StrokeStyle(lineWidth: 1.5, dash: [4, 3])
    }

    private var markerEvents: [HealthEvent] {
        visibleEvents.filter { usesCondensedEventMarkers || !$0.isPeriod }
    }

    /// 长跨度下以时间段中点作为代表日期；保留真实日期，避免多个事件吸附到同一月度点后重叠。
    private func eventMarkerDate(_ event: HealthEvent) -> Date {
        let end = event.endDate ?? event.startDate
        return event.startDate.addingTimeInterval(end.timeIntervalSince(event.startDate) / 2)
    }

    /// 把点选日期映射到事件：优先命中时间段色带，其次就近命中单日事件。
    private func eventHit(at date: Date) -> HealthEvent? {
        if !usesCondensedEventMarkers, let period = visibleEvents.first(where: { event in
            guard let end = event.endDate else { return false }
            return date >= event.startDate && date <= end
        }) {
            return period
        }
        let span = range.visibleDomainSeconds ?? visibleWindow.upperBound.timeIntervalSince(visibleWindow.lowerBound)
        let tolerance = span * (usesCondensedEventMarkers ? 0.04 : 0.12)
        let nearest = markerEvents.min {
            abs(eventMarkerDate($0).timeIntervalSince(date)) < abs(eventMarkerDate($1).timeIntervalSince(date))
        }
        if let nearest, abs(eventMarkerDate(nearest).timeIntervalSince(date)) <= tolerance {
            return nearest
        }
        return nil
    }

    /// 仅在分页（周/月/年）时启用横向滚动与固定可视窗口；「全部」一次展示完整数据。
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

    private var axisStride: AxisMarkValues {
        switch range {
        case .week:        return .stride(by: .day)
        case .month:       return .stride(by: .day, count: 7)
        case .year:        return .stride(by: .month)
        case .all:         return .stride(by: .year)
        }
    }

    /// 在日期两侧的趋势样本间做线性插值，让长跨度事件点贴近对应曲线且不改变横坐标。
    private func weightOnTrend(at date: Date) -> Double {
        guard let first = sortedSamples.first, let last = sortedSamples.last else {
            return yDomain.upperBound
        }
        if date <= first.date { return first.kg }
        if date >= last.date { return last.kg }
        guard let upperIndex = sortedSamples.firstIndex(where: { $0.date >= date }), upperIndex > 0 else {
            return first.kg
        }
        let lower = sortedSamples[upperIndex - 1]
        let upper = sortedSamples[upperIndex]
        let span = upper.date.timeIntervalSince(lower.date)
        guard span > 0 else { return upper.kg }
        let progress = date.timeIntervalSince(lower.date) / span
        return lower.kg + (upper.kg - lower.kg) * progress
    }

    private func axisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        switch range {
        case .week:  formatter.dateFormat = "EEE"   // 周一…周日
        case .month: formatter.dateFormat = "d日"
        case .year:  formatter.dateFormat = "M月"
        case .all:   formatter.dateFormat = "yyyy"
        }
        return formatter.string(from: date)
    }
}
