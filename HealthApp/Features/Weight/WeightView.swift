// WeightView.swift
// 体重长期趋势与事件叠加。PRD §5.2 / §8.3。

import SwiftUI

struct WeightView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = WeightViewModel()
    @State private var selectedRange: TimeRange = .week
    @State private var showsEvents = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    rangePicker
                    chartCard
                    impactCard
                    statisticsCard
                    recentRecordsCard
                    insightCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.appBg.ignoresSafeArea())
            .navigationTitle("体重")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { appState.presentEventEditor() } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 34, height: 34)
                            .foregroundColor(.white)
                            .background(Color.brandBlue)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("记录事件")
                }
            }
            .task { await viewModel.loadInitialData(from: appState.repository) }
            .task(id: selectedRange) {
                await viewModel.loadSeries(for: selectedRange, from: appState.repository)
            }
        }
    }

    private var rangePicker: some View {
        Picker("时间范围", selection: $selectedRange) {
            ForEach(TimeRange.allCases) { range in
                Text(range.label).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .tint(.brandBlue)
        .accessibilityLabel("体重时间范围")
    }

    private var chartCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("体重趋势")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Toggle("在图上显示事件", isOn: $showsEvents)
                        .labelsHidden()
                        .tint(.brandBlue)
                    Text("事件")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textSecondary)
                }

                if viewModel.isLoading && viewModel.samples.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 230)
                } else if viewModel.samples.isEmpty {
                    Text("暂无体重数据")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 230)
                } else {
                    WeightChart(samples: viewModel.samples,
                                goalWeight: appState.goalWeight,
                                events: appState.events,
                                showsEvents: showsEvents,
                                range: selectedRange)
                        .frame(height: 230)
                        .animation(.easeInOut(duration: 0.25), value: selectedRange)
                        .animation(.easeInOut(duration: 0.2), value: showsEvents)
                }

                HStack(spacing: 14) {
                    legendLine(color: .brandBlue, title: "体重")
                    legendLine(color: .exerciseOrange, title: "目标", dashed: true)
                    if showsEvents {
                        eventLegend
                    }
                }
            }
        }
    }

    private func legendLine(color: Color, title: String, dashed: Bool = false) -> some View {
        HStack(spacing: 5) {
            Rectangle()
                .fill(color)
                .frame(width: 16, height: dashed ? 1 : 2)
                .overlay {
                    if dashed {
                        Rectangle().stroke(color, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    }
                }
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.textSecondary)
        }
    }

    private var eventLegend: some View {
        HStack(spacing: 9) {
            ForEach(EventType.allCases.filter { $0 != .other }, id: \.self) { type in
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

    private func legendTitle(for type: EventType) -> String {
        switch type {
        case .injury, .travel: return "\(type.label)(段)"
        default: return type.label
        }
    }

    private var impactCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "cross.case.fill")
                .foregroundColor(.eventIllness)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text("5月31日 · 感冒发烧")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.textPrimary)
                Text("病后一周运动暂停，体重回升 0.6kg。点查看 ›")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.eventIllnessBg)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.eventIllness.opacity(0.22), lineWidth: 1)
        )
    }

    private var statisticsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("体重统计")
                HStack(spacing: 0) {
                    statistic(title: "当前", value: viewModel.currentWeight, color: .brandBlue)
                    statistic(title: "累计", value: viewModel.cumulativeChange, color: .successGreen, signed: true)
                    statistic(title: "历史最低", value: viewModel.historicalLow, color: .textPrimary)
                }
                Divider().background(Color.hairline)
                HStack {
                    Text("历史最高")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textSecondary)
                    Spacer()
                    Text(Self.weightText(viewModel.historicalHigh) + " kg")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.textPrimary)
                }
            }
        }
    }

    private func statistic(title: String, value: Double?, color: Color, signed: Bool = false) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(signed ? Self.signedWeightText(value) : Self.weightText(value))
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

    private static func weightText(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.1f", value)
    }

    private static func signedWeightText(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%+.1f", value)
    }
}
