// ExerciseView.swift
// 运动消耗、时长、心率、类型与事件影响。PRD §5.4。

import SwiftUI

enum ExerciseMetric: String, CaseIterable, Identifiable {
    case kcal
    case heartRate

    var id: String { rawValue }
    var title: String { self == .kcal ? "千卡" : "心率" }
}

private enum ExercisePeriod: Int, CaseIterable, Identifiable {
    case threeMonths = 3
    case sixMonths = 6

    var id: Int { rawValue }
    var title: String { self == .threeMonths ? "近3月" : "近6月" }
}

struct ExerciseView: View {
    @EnvironmentObject private var appState: AppState
    @State private var metric: ExerciseMetric = .kcal
    @State private var period: ExercisePeriod = .sixMonths
    @State private var samples: [ExerciseSample] = []
    @State private var isLoading = false

    private var displayedSamples: [ExerciseSample] {
        Array(samples.suffix(period.rawValue))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    filters
                    heroCard
                    statisticsCard
                    chartCard
                    activityTypesCard
                    eventImpactCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.appBg.ignoresSafeArea())
            .navigationTitle("运动")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { appState.presentEventEditor() } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 34, height: 34)
                            .foregroundColor(.white)
                            .background(Color.exerciseOrange)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("记录事件")
                }
            }
            .task { await loadSamples() }
        }
    }

    private var filters: some View {
        HStack(spacing: 10) {
            Picker("时间范围", selection: $period) {
                ForEach(ExercisePeriod.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)

            Picker("指标", selection: $metric) {
                ForEach(ExerciseMetric.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
        }
        .tint(.exerciseOrange)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("日均消耗 · 近30天")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.82))
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("434")
                            .font(.system(size: 42, weight: .heavy))
                        Text("千卡")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Text("本周 5 次")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.17))
                        .clipShape(Capsule())
                    Text("日均 68 分")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.84))
                }
                .foregroundColor(.white)
            }

            HStack(spacing: 8) {
                Image(systemName: "figure.run")
                Text("主要在中午运动 · 有氧占 66%")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white.opacity(0.88))
        }
        .padding(18)
        .background(
            LinearGradient(colors: [.exerciseOrange, .exerciseOrange.opacity(0.78)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.exerciseOrange.opacity(0.23), radius: 14, x: 0, y: 7)
    }

    private var statisticsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("运动统计")
                HStack(spacing: 0) {
                    stat(title: "日均时长", value: "68", unit: "分")
                    stat(title: "有氧心率", value: "121", unit: "bpm")
                    stat(title: "累计消耗", value: "39.5", unit: "千")
                }
            }
        }
    }

    private func stat(title: String, value: String, unit: String) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(.exerciseOrange)
                Text(unit)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var chartCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(metric == .kcal ? "月度消耗" : "平均心率")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Text(metric == .kcal ? "千卡" : "bpm")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textSecondary)
                }

                if isLoading && samples.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    ExerciseChart(samples: displayedSamples,
                                  metric: metric,
                                  events: appState.events)
                        .frame(height: 200)
                        .animation(.easeInOut(duration: 0.25), value: metric)
                        .animation(.easeInOut(duration: 0.25), value: period)
                }

                HStack(spacing: 16) {
                    legend(color: .exerciseOrange, title: metric == .kcal ? "消耗" : "心率")
                    legend(color: .eventInjury, title: "损伤事件", diamond: true)
                }
            }
        }
    }

    private func legend(color: Color, title: String, diamond: Bool = false) -> some View {
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

    private var activityTypesCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle("运动类型")
                HStack(spacing: 10) {
                    activityType(icon: "figure.run", title: "跑步", count: "3次", progress: 0.6)
                    activityType(icon: "dumbbell.fill", title: "力量", count: "1次", progress: 0.2)
                    activityType(icon: "bicycle", title: "骑行", count: "1次", progress: 0.2)
                }
                Text("有氧占 66% · 累计燃脂约 5.1kg")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
        }
    }

    private func activityType(icon: String, title: String, count: String, progress: Double) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.exerciseOrange)
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.textPrimary)
            Text(count)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.textSecondary)
            ProgressView(value: progress)
                .tint(.exerciseOrange)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.exerciseOrange.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var eventImpactCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "bandage.fill")
                .foregroundColor(.eventInjury)
            VStack(alignment: .leading, spacing: 4) {
                Text(injuryEventTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.textPrimary)
                Text("期间运动暂停，周消耗降到平时 1/3。")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.eventInjuryBg)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.eventInjury.opacity(0.22), lineWidth: 1)
        )
    }

    private var injuryEventTitle: String {
        let event = appState.events.first { $0.type == .injury }
        return event.map { "5月20–27日 · \($0.title)" } ?? "5月20–27日 · 腰肌肉拉伤"
    }

    private func loadSamples() async {
        isLoading = true
        samples = await appState.repository.exerciseSeries(range: .all)
        isLoading = false
    }
}
