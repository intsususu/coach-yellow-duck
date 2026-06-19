// SleepView.swift
// 睡眠时长、效率、阶段分解与事件影响。PRD §5.3。

import SwiftUI

struct SleepView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedRange: TimeRange = .month
    @State private var samples: [SleepSample] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    rangePicker
                    heroCard
                    stageCard
                    nightlyChartCard
                    eventImpactCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.appBg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task(id: selectedRange) { await loadSamples() }
        }
    }

    private var rangePicker: some View {
        Picker("时间范围", selection: $selectedRange) {
            Text("周").tag(TimeRange.week)
            Text("月").tag(TimeRange.month)
            Text("年").tag(TimeRange.year)
        }
        .pickerStyle(.segmented)
        .tint(.sleepIndigo)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("平均睡眠 · 近14晚")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.82))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("7.3")
                            .font(.system(size: 42, weight: .heavy))
                        Text("小时")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    Text("↑0.2h")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Text("效率 95%")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.17))
                        .clipShape(Capsule())
                    Text("夜醒 8.3 次")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.82))
                }
                .foregroundColor(.white)
            }

            stageBar(onHero: true)
        }
        .padding(18)
        .background(
            LinearGradient(colors: [.sleepIndigo, .sleepIndigo.opacity(0.78)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.sleepIndigo.opacity(0.25), radius: 14, x: 0, y: 7)
    }

    private var stageCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle("睡眠阶段 · 日均")
                stageBar(onHero: false)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    stageMetric(title: "深睡", value: "0.65h", detail: "约 41 分 · 偏少 · 建议↑", color: .sleepIndigo)
                    stageMetric(title: "核心", value: "4.67h", detail: "约 280 分", color: .brandBlue)
                    stageMetric(title: "REM", value: "1.58h", detail: "约 100 分 · 正常区间", color: .eventDrink)
                    stageMetric(title: "清醒", value: "0.36h", detail: "约 21 分", color: .textMuted)
                }
            }
        }
    }

    private func stageBar(onHero: Bool) -> some View {
        VStack(spacing: 7) {
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    stageSegment(width: geometry.size.width * 0.089, color: onHero ? .white.opacity(0.95) : .sleepIndigo)
                    stageSegment(width: geometry.size.width * 0.643, color: onHero ? .white.opacity(0.68) : .brandBlue.opacity(0.8))
                    stageSegment(width: geometry.size.width * 0.217, color: onHero ? .white.opacity(0.43) : .eventDrink.opacity(0.7))
                    stageSegment(width: geometry.size.width * 0.051, color: onHero ? .white.opacity(0.24) : .textMuted.opacity(0.55))
                }
            }
            .frame(height: 12)

            HStack {
                ForEach(["深睡", "核心", "REM", "清醒"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(onHero ? .white.opacity(0.8) : .textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func stageSegment(width: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(color)
            .frame(width: max(width - 2, 3))
    }

    private func stageMetric(title: String, value: String, detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textSecondary)
            Text(value)
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(color)
            Text(detail)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(detail.contains("偏少") ? .eventIllness : .textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var nightlyChartCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("每晚时长")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Text(selectedRange == .week ? "近 7 晚" : "近 14 晚")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textSecondary)
                }

                if isLoading && samples.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 190)
                } else {
                    SleepChart(samples: samples, events: appState.events)
                        .frame(height: 190)
                        .animation(.easeInOut(duration: 0.25), value: selectedRange)
                }

                HStack(spacing: 16) {
                    chartLegend(color: .sleepIndigo, title: "睡眠")
                    chartLegend(color: .eventTravelBg, title: "旅行区间")
                    chartLegend(color: .eventDrink, title: "饮酒事件", diamond: true)
                }
            }
        }
    }

    private func chartLegend(color: Color, title: String, diamond: Bool = false) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
                .rotationEffect(.degrees(diamond ? 45 : 0))
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.textSecondary)
        }
    }

    private var eventImpactCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wineglass.fill")
                .foregroundColor(.eventDrink)
            VStack(alignment: .leading, spacing: 4) {
                Text(drinkEventTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.textPrimary)
                Text("当晚深睡 ↓、清醒增多，睡眠效率降到 88%。")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.eventDrinkBg)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.eventDrink.opacity(0.2), lineWidth: 1)
        )
    }

    private var drinkEventTitle: String {
        let event = appState.events.first { $0.type == .drink }
        return event.map { "6月7日 · \($0.title.replacingOccurrences(of: " · ", with: "（"))" + ($0.title.contains(" · ") ? "）" : "") }
            ?? "6月7日 · 饮酒（聚餐）"
    }

    private func loadSamples() async {
        isLoading = true
        samples = await appState.repository.sleepSeries(range: selectedRange)
        isLoading = false
    }
}
