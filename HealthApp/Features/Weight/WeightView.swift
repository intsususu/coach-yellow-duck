// WeightView.swift
// 体重长期趋势与事件叠加。PRD §5.2 / §8.3。

import SwiftUI

struct WeightView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = WeightViewModel()
    @State private var selectedRange: TimeRange = .month
    /// 图表实际渲染的范围；仅在新数据和滚动位置都就绪后更新。
    @State private var chartRange: TimeRange = .month
    /// 是否叠加事件：全局开关，由首页顶部控制，各趋势页共用。
    private var showsEvents: Bool { appState.showsEvents }
    /// 趋势图可视窗口前沿（leading edge）；随手势滑动更新，并驱动右下角事件图例的过滤。
    @State private var scrollPosition = Date()
    /// 在图上点选的事件；非空且事件开关打开时，卡片下方展示其详情。
    @State private var selectedEvent: HealthEvent?
    /// 点击图例时选中的基础类型；与图上单条事件选中互斥。
    @State private var selectedLegendType: EventType?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    rangePicker
                    chartCard
                    eventDetailCard
                    statisticsCard
                    recentRecordsCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .animation(.easeInOut(duration: 0.2), value: selectedEvent)
                .animation(.easeInOut(duration: 0.2), value: selectedLegendType)
            }
            .refreshable { await refresh() }
            .background(Color.appBg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task { await viewModel.loadInitialData(from: appState.repository) }
            .task(id: selectedRange) {
                selectedEvent = nil
                selectedLegendType = nil
                let requestedRange = selectedRange
                let didCommit = await viewModel.loadSeries(for: requestedRange,
                                                           from: appState.repository)
                guard didCommit, !Task.isCancelled, selectedRange == requestedRange else { return }
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    resetScrollToLatest(for: requestedRange)
                    chartRange = requestedRange
                }
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
        }
    }

    private func refresh() async {
        selectedEvent = nil
        selectedLegendType = nil
        await appState.repository.refreshCachedData()
        await appState.loadInitialData()
        await viewModel.loadInitialData(from: appState.repository, forceReload: true)

        let requestedRange = selectedRange
        let didCommit = await viewModel.loadSeries(for: requestedRange,
                                                   from: appState.repository)
        guard didCommit, !Task.isCancelled, selectedRange == requestedRange else { return }
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            resetScrollToLatest(for: requestedRange)
            chartRange = requestedRange
        }
    }

    private var rangePicker: some View {
        TrendRangePicker(selection: $selectedRange,
                         accent: .weightGreen,
                         accessibilityLabel: "体重时间范围")
    }

    private var chartCard: some View {
        TrendChartCard(title: "体重趋势",
                       accent: .weightGreen,
                       background: .weightCardBg,
                       isLoading: viewModel.isLoading,
                       isEmpty: viewModel.samples.isEmpty,
                       emptyText: "暂无体重数据") {
            WeightChart(samples: viewModel.samples,
                        events: appState.events,
                        showsEvents: showsEvents,
                        range: chartRange,
                        scrollPosition: $scrollPosition,
                        selectedEvent: $selectedEvent)
                // 每个范围使用独立 Charts 实例，不沿用上一范围的坐标轴和滚动内部状态。
                .id(chartRange)
                .animation(.easeInOut(duration: 0.2), value: showsEvents)
        } legend: {
            HStack(spacing: 14) {
                legendLine(color: .weightGreen, title: "体重")
                if showsEvents {
                    eventLegend
                }
            }
        }
    }

    private func legendLine(color: Color, title: String) -> some View {
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

    /// 仅返回当前可视窗口内出现过的事件类型（排除「其他」），按枚举顺序排列。
    private var windowEventTypes: [EventType] {
        let present = Set(windowEvents.map(\.type))
        return EventType.allCases.filter { present.contains($0) }
    }

    private var windowEvents: [HealthEvent] {
        let window = visibleWindow
        return appState.events.filter { event in
            guard event.type != .other else { return false }
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

    /// 当前趋势图可视窗口区间。「全部」无固定窗口，返回全量事件区间。
    private var visibleWindow: ClosedRange<Date> {
        guard let seconds = chartRange.visibleDomainSeconds else {
            return Date.distantPast...Date.distantFuture
        }
        return scrollPosition...scrollPosition.addingTimeInterval(seconds)
    }

    /// 切换时间范围或重载数据后，把窗口对齐到最新一段（右端贴齐最后样本）。
    private func resetScrollToLatest(for range: TimeRange) {
        guard let last = viewModel.samples.map(\.date).max(),
              let seconds = range.visibleDomainSeconds else { return }
        // 右端留出与 WeightChart 同比例的留白，最后一个圆点不再贴边被裁。
        scrollPosition = last.addingTimeInterval(seconds * WeightChart.trailingPadFactor - seconds)
    }

    /// 点图上事件展示单条；点图例展示当前窗口内该基础类型的全部事件。
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
                            Text("\(Self.eventDateText(for: event)) · \(event.type.label)")
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

    private func clearEventSelection() {
        selectedEvent = nil
        selectedLegendType = nil
    }

    private var statisticsCard: some View {
        let stats = viewModel.statistics
        return CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("体重统计")
                HStack(spacing: 0) {
                    statistic(title: "当前", value: stats.current, color: .weightGreen)
                    statistic(title: "今年最低", value: stats.yearLow, color: .textPrimary)
                    statistic(title: "历史最低", value: stats.allTimeLow, color: .textPrimary)
                }
                Divider().background(Color.hairline)
                HStack(spacing: 0) {
                    statistic(title: "今年最高", value: stats.yearHigh, color: .textPrimary)
                    statistic(title: "历史最高", value: stats.allTimeHigh, color: .textPrimary)
                    statistic(title: "累计减少", value: stats.cumulativeLoss, color: .successGreen)
                }
            }
        }
    }

    private func statistic(title: String, value: Double?, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(Self.weightText(value))
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(color)
                Text("kg")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var recentRecordsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 4) {
                SectionTitle("最近记录")
                    .padding(.bottom, 4)
                ForEach(Array(viewModel.recentRecords.enumerated()), id: \.element.id) { index, sample in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Self.recordDateFormatter.string(from: sample.date))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            if index == 0 {
                                Text("最新记录")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.weightGreen)
                            }
                        }
                        Spacer()
                        Text(Self.weightText(sample.kg) + " kg")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(index == 0 ? .weightGreen : .textPrimary)
                    }
                    .padding(.vertical, 8)
                    if index < viewModel.recentRecords.count - 1 {
                        Divider().background(Color.hairline)
                    }
                }
            }
        }
    }

    private static let recordDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月dd日"
        return formatter
    }()

    private static func eventDateText(for event: HealthEvent) -> String {
        let start = recordDateFormatter.string(from: event.startDate)
        guard let endDate = event.endDate else { return start }
        return "\(start)–\(recordDateFormatter.string(from: endDate))"
    }

    private static func weightText(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.1f", value)
    }
}
