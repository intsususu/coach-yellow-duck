// SleepView.swift
// 睡眠时长、效率、阶段分解与事件影响。PRD §5.3。

import SwiftUI

struct SleepView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedRange: SleepRange = .week
    @State private var dailySamples: [SleepSample] = []
    @State private var qualityScores: [SleepQualityScore] = []
    @State private var isLoading = false
    /// 默认展示睡眠质量分；打开后，周 / 月切换为现有睡眠阶段趋势。
    @State private var showsSleepStages = false
    /// 是否叠加事件：全局开关，由首页顶部控制，各趋势页共用。
    private var showsEvents: Bool { appState.showsEvents }
    /// 趋势图可视窗口前沿（leading edge）；随手势更新，驱动事件图例过滤。
    @State private var scrollPosition = Date()
    /// 在图上点选的事件；非空且事件开关打开时，图下方展示其详情。
    @State private var selectedEvent: HealthEvent?
    /// 点击图例时选中的基础类型；与图上单条事件选中互斥。
    @State private var selectedLegendType: EventType?
    /// 当前周期低质量评分卡是否展开。
    @State private var isLowQualityAnalysisExpanded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    rangePicker
                    trendChartCard
                    eventDetailCard
                    lowQualityAnalysisCard
                    summaryCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .animation(.easeInOut(duration: 0.2), value: selectedEvent)
                .animation(.easeInOut(duration: 0.2), value: selectedLegendType)
            }
            .refreshable { await refresh() }
            .background(Color.appBg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task {
                selectedEvent = nil
                selectedLegendType = nil
                await loadSamples()
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
            .onChange(of: selectedRange) { range in
                if range == .sixMonths { showsSleepStages = false }
                clearEventSelection()
                isLowQualityAnalysisExpanded = false
                resetScrollToLatest()
            }
            .onChange(of: showsSleepStages) { _ in
                clearEventSelection()
                isLowQualityAnalysisExpanded = false
            }
        }
    }

    private func refresh() async {
        clearEventSelection()
        await appState.repository.refreshCachedData()
        await appState.loadInitialData()
        await loadSamples()
        guard !Task.isCancelled else { return }
        resetScrollToLatest()
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
                           color: .sleepCore,
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
                           value: avgBedtime, unit: "",
                           detail: "平均上床",
                           color: .sleepCore,
                           trend: bedtimeSeries)
            longMetricCard(title: "平均起床时间",
                           value: avgWakeTime, unit: "",
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

    /// 统计窗口内的样本。周 / 月跟随上方趋势图的横向滑动，6 个月保持完整窗口口径。
    private var windowSamples: [SleepSample] {
        let sorted = dailySamples.sorted { $0.date < $1.date }
        guard selectedRange.visibleDomainSeconds != nil else {
            return Array(sorted.suffix(windowDayCount))
        }

        // 图表可视域两端含防裁切留白；扣除右侧留白后，以当前窗口最后一晚为锚点回取固定晚数。
        let windowEnd = visibleWindow.upperBound.addingTimeInterval(-selectedRange.edgePaddingSeconds)
        guard let endIndex = sorted.lastIndex(where: { $0.date <= windowEnd }) else { return [] }
        let startIndex = max(sorted.startIndex, endIndex - windowDayCount + 1)
        return Array(sorted[startIndex...endIndex])
    }

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

    // 夜醒次数模型未记录，沿用高保真原型代表值（参见 hybrid 派生策略）。
    private static let avgAwakeCount = 8

    /// 平均入睡时间：窗口内有入睡时刻的夜晚均值；无数据显示「—」。读取 HealthKit `sleepAnalysis`。
    private var avgBedtime: String { Self.formatClock(averageClockMinutes(windowSamples.compactMap(\.bedtime))) }
    /// 平均起床时间：窗口内有起床时刻的夜晚均值；无数据显示「—」。读取 HealthKit `sleepAnalysis`。
    private var avgWakeTime: String { Self.formatClock(averageClockMinutes(windowSamples.compactMap(\.wakeTime))) }

    /// 把一组时刻按「自中午起算的分钟」求平均，返回 0–1439 的当日分钟数；无样本返回 nil。
    /// 以中午为锚使 23:xx 与次日 00:xx 在数轴上连续，避免跨午夜平均失真（清晨时刻同样适用）。
    private func averageClockMinutes(_ dates: [Date]) -> Double? {
        guard !dates.isEmpty else { return nil }
        let avg = dates.map(Self.minutesFromNoon).reduce(0, +) / Double(dates.count)
        return (avg + 720).truncatingRemainder(dividingBy: 1440)
    }

    /// 把当日分钟数格式化为「HH:mm」；nil 显示占位「—」。
    private static func formatClock(_ minutesOfDay: Double?) -> String {
        guard let minutesOfDay else { return "—" }
        let total = (Int(minutesOfDay.rounded()) % 1440 + 1440) % 1440
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// 时刻 → 自中午起算的分钟（0–1439），使跨午夜的入睡时刻在数轴上连续。
    private static func minutesFromNoon(_ date: Date) -> Double {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        let m = Double((c.hour ?? 0) * 60 + (c.minute ?? 0))
        return (m - 720 + 1440).truncatingRemainder(dividingBy: 1440)
    }

    /// 时刻 → 自零点起算的分钟（0–1439），用于不跨午夜的清晨起床时刻。
    private static func minutesFromMidnight(_ date: Date) -> Double {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Double((c.hour ?? 0) * 60 + (c.minute ?? 0))
    }

    // MARK: - 卡片背景趋势序列（按晚，最早 → 最新）

    private var totalHoursSeries: [Double] { windowSamples.map(\.totalHours) }
    private var deepSeries: [Double] { windowSamples.compactMap { $0.deepMinutes.map(Double.init) } }
    private var awakeSeries: [Double] { windowSamples.compactMap { $0.awakeMinutes.map(Double.init) } }

    /// 入睡时刻序列：以「中午起算的分钟」表示，使 23:xx 与次日 00:xx 在数轴上连续——跨天不产生断点。
    private var bedtimeSeries: [Double] {
        windowSamples.compactMap { $0.bedtime.map(Self.minutesFromNoon) }
    }
    /// 起床时刻序列：清晨不跨天，直接用「自零点起算的分钟」。
    private var wakeSeries: [Double] {
        windowSamples.compactMap { $0.wakeTime.map(Self.minutesFromMidnight) }
    }

    // MARK: - 趋势图卡片

    private var trendChartCard: some View {
        CardView(background: .sleepCardBg) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text("睡眠质量趋势")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("睡眠阶段")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.textSecondary)
                            .accessibilityHidden(true)
                        Toggle("", isOn: $showsSleepStages)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(.sleepIndigo)
                            .controlSize(.mini)
                            .accessibilityLabel("睡眠阶段")
                    }
                    .fixedSize()
                    .disabled(selectedRange == .sixMonths)
                    .opacity(selectedRange == .sixMonths ? 0.55 : 1)
                    .accessibilityHint(selectedRange == .sixMonths
                                       ? "睡眠阶段仅支持周和月"
                                       : "打开后显示睡眠阶段趋势")
                }

                trendChartArea

                legend
                    .frame(maxWidth: .infinity,
                           minHeight: TrendCardSpec.legendHeight,
                           maxHeight: TrendCardSpec.legendHeight,
                           alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var trendChartArea: some View {
        if isLoading && dailySamples.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity,
                       minHeight: TrendCardSpec.chartHeight,
                       maxHeight: TrendCardSpec.chartHeight)
        } else if dailySamples.isEmpty {
            Text("暂无睡眠数据")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity,
                       minHeight: TrendCardSpec.chartHeight,
                       maxHeight: TrendCardSpec.chartHeight)
        } else {
            sleepChart(mode: showsSleepStages ? .stages : .quality)
                .frame(height: TrendCardSpec.chartHeight)
                // 不在不同数据序列间做形状插值，避免周 / 月切换时折线交叉乱飞。
                .transaction { $0.animation = nil }
        }
    }

    private func sleepChart(mode: SleepChartMode) -> some View {
        SleepChart(dailySamples: dailySamples,
                   weeklyAverages: weeklyAverages,
                   qualityScores: qualityScores,
                   events: appState.events,
                   showsEvents: showsEvents,
                   range: selectedRange,
                   mode: mode,
                   scrollPosition: $scrollPosition)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            if !showsSleepStages {
                lineLegend(color: .sleepIndigo, title: "睡眠质量分")
            } else if selectedRange.isWeeklyAverage {
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

    /// 当前周 / 月存在低于 70 分的夜晚时，显示紧凑的周期分析入口。
    @ViewBuilder
    private var lowQualityAnalysisCard: some View {
        let scores = currentLowQualityScores
        if !scores.isEmpty {
            CardView(background: .cardBg, padding: 0) {
                VStack(spacing: 0) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isLowQualityAnalysisExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.sleepAwake)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Color.sleepAwake.opacity(0.1)))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("当周期低质量评分分析")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.textPrimary)
                                Text("\(scores.count) 个评分日低于 70 分")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.textMuted)
                                .rotationEffect(.degrees(isLowQualityAnalysisExpanded ? 180 : 0))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("当周期低质量评分分析，\(scores.count) 个评分日")

                    if isLowQualityAnalysisExpanded {
                        Divider().background(Color.hairline)
                        VStack(spacing: 0) {
                            ForEach(Array(scores.enumerated()), id: \.element.date) { index, score in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 10) {
                                        Text(Self.lowQualityDateFormatter.string(from: score.date))
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.textPrimary)
                                        Spacer()
                                        Text("\(Int(score.score)) 分")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.sleepAwake)
                                    }

                                    Text(Self.lowQualityBasisText(score))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.textSecondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.82)

                                    lowQualityStageGraphic(for: score)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)

                                if index < scores.count - 1 {
                                    Divider()
                                        .background(Color.hairline)
                                        .padding(.leading, 14)
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func lowQualityStageGraphic(for score: SleepQualityScore) -> some View {
        if let sample = dailySamples.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: score.date)
        }) {
            VStack(spacing: 5) {
                SleepStageCompositionBar(sample: sample)
                HStack(spacing: 8) {
                    stageLegendItem("深", minutes: sample.deepMinutes, color: .sleepDeep)
                    stageLegendItem("核心", minutes: sample.coreMinutes, color: .sleepCore)
                    stageLegendItem("REM", minutes: sample.remMinutes, color: .sleepREM)
                    stageLegendItem("醒", minutes: sample.awakeMinutes, color: .sleepAwake)
                }
            }
            .padding(.top, 2)
        }
    }

    private func stageLegendItem(_ title: String, minutes: Int?, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text("\(title) \(minutes ?? 0)分")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.textMuted)
                .lineLimit(1)
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
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(first.type.color.opacity(0.75))
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(first.type.color.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 8)

                ForEach(Array(detailEvents.enumerated()), id: \.element.id) { index, event in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: event.type.sfSymbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(event.type.color)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(event.type.color.opacity(0.16)))

                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 7) {
                                Text(event.type.label)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.textPrimary)
                                    .lineLimit(1)
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
                                    .lineLimit(1)
                                    .frame(height: 16, alignment: .top)
                            } else {
                                Color.clear
                                    .frame(height: 16)
                                    .accessibilityHidden(true)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 52, alignment: .top)
                    if index < detailEvents.count - 1 {
                        Divider().background(Color.hairline)
                    }
                }
            }
            .padding(.vertical, 14)
            .padding(.leading, 16)
            .padding(.trailing, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(first.type.backgroundColor)
            )
            // 左缘强调色条：呼应图上选中事件的虚线，强化「这是被选中的那条」。
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(first.type.color)
                    .frame(width: 4)
                    .padding(.vertical, 13)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(first.type.color.opacity(0.18), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - 派生数据

    private var currentLowQualityScores: [SleepQualityScore] {
        guard !showsSleepStages, selectedRange != .sixMonths else { return [] }
        let dates = Set(windowSamples.map(\.date))
        return qualityScores
            .filter { dates.contains($0.date) && $0.score < 70 }
            .sorted { $0.date > $1.date }
    }

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

    /// 当前可视窗口内出现过的事件类型，按枚举顺序排列。
    private var windowEventTypes: [EventType] {
        let present = Set(windowEvents.map(\.type))
        return EventType.allCases.filter { present.contains($0) }
    }

    private var windowEvents: [HealthEvent] {
        let window = visibleWindow
        return appState.events.filter { event in
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

    private static let lowQualityDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }()

    private static func lowQualityBasisText(_ score: SleepQualityScore) -> String {
        let duration = Int(score.durationScore.rounded())
        let consistency = Int(score.consistencyScore.rounded())
        let interruptions = Int(score.interruptionsScore.rounded())
        let rawTotal = score.durationScore + score.consistencyScore + score.interruptionsScore
        let protection = rawTotal < 50 ? " · 最低分保护" : ""
        return "时长 \(duration)/50 · 一致性 \(consistency)/30 · 中断 \(interruptions)/20\(protection)"
    }

    private static func eventDateText(for event: HealthEvent) -> String {
        let start = eventDateFormatter.string(from: event.startDate)
        guard let endDate = event.endDate else { return start }
        return "\(start)–\(eventDateFormatter.string(from: endDate))"
    }

    private func loadSamples() async {
        isLoading = true
        let samples = await appState.repository.sleepSeries(range: .year)
        guard !Task.isCancelled else { return }
        dailySamples = samples
        qualityScores = SleepQualityCalculator.scores(for: samples)
        isLoading = false
    }
}

/// 使用真实阶段总分钟数绘制紧凑比例条；不冒充缺失的逐段时间轴。
private struct SleepStageCompositionBar: View {
    let sample: SleepSample

    private var segments: [(minutes: Int, color: Color)] {
        [
            (sample.deepMinutes ?? 0, .sleepDeep),
            (sample.coreMinutes ?? 0, .sleepCore),
            (sample.remMinutes ?? 0, .sleepREM),
            (sample.awakeMinutes ?? 0, .sleepAwake),
        ].filter { $0.minutes > 0 }
    }

    var body: some View {
        GeometryReader { geometry in
            let spacing = CGFloat(max(segments.count - 1, 0)) * 2
            let availableWidth = max(geometry.size.width - spacing, 0)
            let total = max(segments.reduce(0) { $0 + $1.minutes }, 1)

            HStack(spacing: 2) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(segment.color)
                        .frame(width: availableWidth * CGFloat(segment.minutes) / CGFloat(total))
                }
            }
        }
        .frame(height: 10)
        .padding(2)
        .background(Capsule().fill(Color.hairline.opacity(0.7)))
        .clipShape(Capsule())
        .accessibilityLabel("睡眠阶段构成")
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
