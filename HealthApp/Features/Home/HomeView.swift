// HomeView.swift
// Tab1 总览仪表盘（A1）。PRD §5.1。替换 T02 占位。

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = HomeViewModel()
    @State private var showsEventTimeline = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                topBar
                heroCard
                ringsCard
                insightCard
                recentEventsCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.appBg.ignoresSafeArea())
        .sheet(isPresented: $showsEventTimeline) {
            EventTimelineView()
        }
        .task { await vm.load(from: appState.repository) }
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
            PillButton(title: "记事件", systemImage: "plus") {
                appState.presentEventEditor()
            }
        }
    }

    // MARK: - 体重 Hero 卡

    private var heroCard: some View {
        Button {
            appState.selectedTab = .weight
        } label: {
            CardView(background: .weightCardBg) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("当前体重")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.textSecondary)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(Self.weightString(vm.stats?.current))
                                    .font(.system(size: 40, weight: .black))
                                    .foregroundColor(.brandBlue)
                                Text("kg")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.brandBlue.opacity(0.7))
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("最近30次 \(Self.deltaString(vm.stats?.recentDelta))")
                            Text("累计 \(Self.signedString(vm.stats?.cumulativeChange))")
                        }
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
                            .foregroundColor(.brandBlue)
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

    // MARK: - 3 圆环指标卡

    private var ringsCard: some View {
        let m = vm.ringMetrics
        return CardView {
            HStack(spacing: 0) {
                RingMetric(value: String(format: "%.1f", m.sleepHours), unit: "h",
                           label: "睡眠", progress: Self.ringProgress(m.sleepHours, m.sleepGoalHours),
                           color: .sleepIndigo)
                RingMetric(value: "\(m.exerciseMinutes)", unit: "m",
                           label: "运动", progress: Self.ringProgress(Double(m.exerciseMinutes), Double(m.exerciseGoalMinutes)),
                           color: .successGreen)
                RingMetric(value: "\(m.activeKcal)", unit: "千卡",
                           label: "卡路里", progress: Self.ringProgress(Double(m.activeKcal), Double(m.activeKcalGoal)),
                           color: .exerciseOrange)
            }
        }
    }

    /// 环进度：值/目标，夹在 [0, 1]（达标即满环，避免目标为 0 时除零）。
    private static func ringProgress(_ value: Double, _ goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return min(1, max(0, value / goal))
    }

    // MARK: - 关联洞察卡（虚线框）

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("本周亮点")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.textPrimary)
            Text("体重连续 4 周下降，运动负荷与睡眠时长同步走高 👍")
                .font(.system(size: 13))
                .foregroundColor(.textPrimary)
            Text("感冒发烧那周运动暂停，体重回升 0.6kg，恢复训练后已回落。")
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
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
                    ForEach(Array(appState.events.prefix(4))) { event in
                        RecentEventRow(event: event)
                        if event.id != appState.events.prefix(4).last?.id {
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

    /// 带符号显示，如 -13.9。
    private static func signedString(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.1f", value)
    }
}
