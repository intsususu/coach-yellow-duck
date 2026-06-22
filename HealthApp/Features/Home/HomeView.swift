// HomeView.swift
// Tab1 总览仪表盘（A1）。PRD §5.1。替换 T02 占位。

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = HomeViewModel()
    @State private var showsEventTimeline = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                topBar
                if Self.isSunday, let report = vm.weeklyReport {
                    weeklySummaryCard(report)
                }
                heroCard
                sleepCard
                exerciseCard
                recentEventsCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .refreshable { await refresh() }
        .background(Color.appBg.ignoresSafeArea())
        .sheet(isPresented: $showsEventTimeline) {
            EventTimelineView()
        }
        .task(id: appState.isInitialLoadComplete) {
            guard appState.isInitialLoadComplete else { return }
            await vm.load(from: appState.repository,
                          events: appState.events,
                          goalWeight: appState.goalWeight)
        }
    }

    private func refresh() async {
        await appState.repository.refreshCachedData()
        await appState.loadInitialData()
        await vm.load(from: appState.repository,
                      events: appState.events,
                      goalWeight: appState.goalWeight)
    }

    // MARK: - 顶部栏

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.dateFormatter.string(from: Date()))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textSecondary)
                Text("\(Self.greeting)，今天")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(.textPrimary)
            }
            Spacer()
            // 趋势图事件叠加的全局开关：原在各趋势卡内，现统一收到首页控制。
            Toggle(isOn: $appState.showsEvents) {
                Text("事件")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .padding(.vertical, 6)
                    .padding(.trailing, 4)
                    .contentShape(Rectangle())
            }
            .tint(.brandBlue)
            .fixedSize()
            .accessibilityLabel("在趋势图上显示事件")
        }
    }

    // MARK: - 体重 Hero 卡

    private var heroCard: some View {
        Button {
            appState.selectedTab = .weight
        } label: {
            CardView(background: .weightCardBg) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 1) {
                            metricTitle(name: "体重", latest: vm.latestWeight)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(Self.weightString(vm.stats?.current))
                                    .font(.system(size: 32, weight: .black))
                                    .foregroundColor(.weightGreen)
                                Text("kg")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.weightGreen.opacity(0.7))
                            }
                        }
                        Spacer()
                        Text("最近30日 \(Self.deltaString(vm.stats?.recentDelta))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.successGreen)
                    }

                    WeightSparkline(samples: vm.sparkline)

                    HStack {
                        Text(goalText)
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                        Spacer()
                        Text("查看趋势 ›")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.weightGreen)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var goalText: String {
        let goal = Int(appState.goalWeight.rounded())
        let dist = vm.stats?.distance(to: appState.goalWeight)
        return "距目标 \(goal)kg · 还差 \(Self.weightString(dist))kg"
    }

    // MARK: - 睡眠指标卡（与体重卡同款，靛蓝主题）

    private var sleepCard: some View {
        let avg = vm.sleepAverage.map { "近30日均 \(String(format: "%.1f", $0))h" } ?? "近30日均 --"
        return metricCard(
            name: "睡眠时长",
            latest: vm.latestSleep,
            value: String(format: "%.1f", vm.latestSleep.value),
            unit: "h",
            badge: avg,
            footnote: "最近 30 日睡眠时长趋势",
            trend: vm.sleepTrend,
            color: .sleepIndigo,
            background: .sleepCardBg,
            tab: .sleep
        )
    }

    // MARK: - 运动指标卡（与体重卡同款，橙色主题）

    private var exerciseCard: some View {
        let avg = vm.energyAverage.map { "近30日均 \(Int($0))千卡" } ?? "近30日均 --"
        return metricCard(
            name: "活动热量",
            latest: vm.latestEnergy,
            value: "\(Int(vm.latestEnergy.value))",
            unit: "千卡",
            badge: avg,
            footnote: "最近 30 日活动热量趋势",
            trend: vm.energyTrend,
            color: .exerciseOrange,
            background: .exerciseCardBg,
            tab: .exercise
        )
    }

    /// 体重卡同款的指标卡：标题 + 大号数值 + 右上角徽标 + 30 日趋势小折线 + 查看趋势。
    private func metricCard(name: String, latest: HomeViewModel.LatestMetric,
                            value: String, unit: String,
                            badge: String, footnote: String, trend: [DailyMetric],
                            color: Color, background: Color, tab: Tab) -> some View {
        Button {
            appState.selectedTab = tab
        } label: {
            CardView(background: background) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 1) {
                            metricTitle(name: name, latest: latest)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(value)
                                    .font(.system(size: 32, weight: .black))
                                    .foregroundColor(color)
                                Text(unit)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(color.opacity(0.7))
                            }
                        }
                        Spacer()
                        Text(badge)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(color)
                    }

                    MetricSparkline(points: trend, color: color)

                    HStack {
                        Text(footnote)
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                        Spacer()
                        Text("查看趋势 ›")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(color)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// 指标卡标题：当日有更新显示「今日 X」；否则显示「最新 X」并在右侧附灰字月日。
    private func metricTitle(name: String, latest: HomeViewModel.LatestMetric) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(latest.isToday ? "今日" : "最新")\(name)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.textSecondary)
            if !latest.isToday, let date = latest.date {
                Text(Self.monthDayFormatter.string(from: date))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.textMuted)
            }
        }
    }

    // MARK: - 本周小结卡（仅周日展示，置顶；内容由综合分析引擎按本周数据生成）

    private func weeklySummaryCard(_ report: AnalysisReport) -> some View {
        Button {
            // 首页和报告页共用同一个报告快照，确保两处文案及返回后的内容完全一致。
            appState.presentAnalysis(report: report)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image("ChickAvatar")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 26, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Text("本周小结")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Text("查看报告")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.brandBlue)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.brandBlue)
                }
                Text(report.narrative)
                    .font(.system(size: 13))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.brandBlue.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.brandBlue.opacity(0.4),
                                  style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 近期事件卡

    private var recentEventsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 4) {
                SectionTitle(title: "近期事件") {
                    PillButton(title: "记录", systemImage: "plus", filled: false) {
                        appState.presentEventEditor()
                    }
                }
                .padding(.bottom, 4)

                if appState.events.isEmpty {
                    Text("暂无事件，点「记录」添加")
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                        .padding(.vertical, 8)
                } else {
                    // 近期事件按事件发生时间（开始日期）倒序，而非录入先后。
                    let recentEvents = Array(appState.events.sorted { $0.startDate > $1.startDate }.prefix(4))
                    ForEach(recentEvents) { event in
                        RecentEventRow(event: event)
                        if event.id != recentEvents.last?.id {
                            Divider().background(Color.hairline)
                        }
                    }
                }
            }
        }
        // 点击卡片（「记录」按钮区域除外）进入事件列表页。
        .contentShape(Rectangle())
        .onTapGesture { showsEventTimeline = true }
    }

    // MARK: - 格式化

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f
    }()

    /// 指标卡「最新」态的灰字月日。
    private static let monthDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f
    }()

    /// 今天是否为周日（周小结仅在周日置顶展示）。
    private static var isSunday: Bool {
        Calendar.current.component(.weekday, from: Date()) == 1
    }

    private static var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<6:   return "夜深了"
        case 6..<12:  return "早上好"
        case 12..<14: return "中午好"
        case 14..<18: return "下午好"
        default:      return "晚上好"
        }
    }

    private static func weightString(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.1f", value)
    }

    /// 本周变化：下降显示 ↓abs，上升显示 ↑abs。
    private static func deltaString(_ value: Double?) -> String {
        guard let value else { return "--" }
        let arrow = value <= 0 ? "↓" : "↑"
        return "\(arrow)\(String(format: "%.1f", abs(value)))"
    }

}
