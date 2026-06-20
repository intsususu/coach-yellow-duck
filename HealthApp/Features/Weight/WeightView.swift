// WeightView.swift
// 体重长期趋势与事件叠加。PRD §5.2 / §8.3。

import SwiftUI

struct WeightView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = WeightViewModel()
    @State private var selectedRange: TimeRange = .month
    @State private var showsEvents = true
    /// 趋势图可视窗口前沿（leading edge）；随手势滑动更新，并驱动右下角事件图例的过滤。
    @State private var scrollPosition = Date()
    /// 在图上点选的事件；非空且事件开关打开时，卡片下方展示其详情。
    @State private var selectedEvent: HealthEvent?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    rangePicker
                    chartCard
                    eventDetailCard
                    statisticsCard
                    recentRecordsCard
                    insightCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .animation(.easeInOut(duration: 0.2), value: selectedEvent)
            }
            .background(Color.appBg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task { await viewModel.loadInitialData(from: appState.repository) }
            .task(id: selectedRange) {
                selectedEvent = nil
                await viewModel.loadSeries(for: selectedRange, from: appState.repository)
                resetScrollToLatest()
            }
            .onChange(of: showsEvents) { isOn in
                if !isOn { selectedEvent = nil }
            }
        }
    }

    private var rangePicker: some View {
        TrendRangePicker(selection: $selectedRange,
                         accent: .brandBlue,
                         accessibilityLabel: "体重时间范围")
    }

    private var chartCard: some View {
        TrendChartCard(title: "体重趋势",
                       accent: .brandBlue,
                       background: .weightCardBg,
                       showsEvents: $showsEvents,
                       isLoading: viewModel.isLoading,
                       isEmpty: viewModel.samples.isEmpty,
                       emptyText: "暂无体重数据") {
            WeightChart(samples: viewModel.samples,
                        events: appState.events,
                        showsEvents: showsEvents,
                        range: selectedRange,
                        scrollPosition: $scrollPosition,
                        selectedEvent: $selectedEvent)
                .animation(.easeInOut(duration: 0.25), value: selectedRange)
                .animation(.easeInOut(duration: 0.2), value: showsEvents)
        } legend: {
            HStack(spacing: 14) {
                legendLine(color: .brandBlue, title: "体重")
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

    /// 仅返回当前可视窗口内出现过的事件类型（排除「其他」），按枚举顺序排列。
    private var windowEventTypes: [EventType] {
        let window = visibleWindow
        let present = Set(
            appState.events
                .filter { event in
                    let end = event.endDate ?? event.startDate
                    return event.startDate <= window.upperBound && end >= window.lowerBound
                }
                .map(\.type)
        ).subtracting([.other])
        return EventType.allCases.filter { present.contains($0) }
    }

    /// 当前趋势图可视窗口区间。「全部」无固定窗口，返回全量事件区间。
    private var visibleWindow: ClosedRange<Date> {
        guard let seconds = selectedRange.visibleDomainSeconds else {
            return Date.distantPast...Date.distantFuture
        }
        return scrollPosition...scrollPosition.addingTimeInterval(seconds)
    }

    /// 切换时间范围或重载数据后，把窗口对齐到最新一段（右端贴齐最后样本）。
    private func resetScrollToLatest() {
        guard let last = viewModel.samples.map(\.date).max(),
              let seconds = selectedRange.visibleDomainSeconds else { return }
        // 右端留出与 WeightChart 同比例的留白，最后一个圆点不再贴边被裁。
        scrollPosition = last.addingTimeInterval(seconds * WeightChart.trailingPadFactor - seconds)
    }

    private func legendTitle(for type: EventType) -> String {
        switch type {
        case .illness, .travel: return "\(type.label)(段)"
        default: return type.label
        }
    }

    /// 事件详情：仅当事件开关打开、且在图上点选了某个事件时展示。
    @ViewBuilder
    private var eventDetailCard: some View {
        if showsEvents, let event = selectedEvent {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: event.type.sfSymbol)
                    .foregroundColor(event.type.color)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(Self.eventDateText(for: event)) · \(event.title)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.textPrimary)
                    if !event.note.isEmpty {
                        Text(event.note)
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                Button {
                    selectedEvent = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(event.type.color.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(event.type.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(event.type.color.opacity(0.22), lineWidth: 1)
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var statisticsCard: some View {
        let stats = viewModel.statistics
        return CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("体重统计")
                HStack(spacing: 0) {
                    statistic(title: "当前", value: stats.current, color: .brandBlue)
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
                                    .foregroundColor(.brandBlue)
                            }
                        }
                        Spacer()
                        Text(Self.weightText(sample.kg) + " kg")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(index == 0 ? .brandBlue : .textPrimary)
                    }
                    .padding(.vertical, 8)
                    if index < viewModel.recentRecords.count - 1 {
                        Divider().background(Color.hairline)
                    }
                }
            }
        }
    }

    private var insightCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.exerciseOrange)
            VStack(alignment: .leading, spacing: 5) {
                Text("关联洞察")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.textPrimary)
                Text("拉伤那周运动暂停，体重回升 0.6kg；出差期间作息乱、下降也停滞。")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandBlue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.brandBlue.opacity(0.18), lineWidth: 1)
        )
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
