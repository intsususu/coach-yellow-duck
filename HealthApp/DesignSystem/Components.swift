// Components.swift
// 基础可复用 UI 组件。PRD §4.3 卡片/圆环/Pill 样式。

import SwiftUI

/// 白底圆角卡片：圆角 16、轻描边 + 轻阴影。可指定背景色（如体重 hero 卡）。
struct CardView<Content: View>: View {
    var background: Color = .cardBg
    var padding: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.hairline, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

/// 环形进度指标：环 + 大号数值 + 单位 + 标签。睡眠/运动/卡路里复用。
struct RingMetric: View {
    let value: String          // 主数值，如 "7.3"
    var unit: String = ""      // 单位，如 "h" / "m" / "千卡"
    let label: String          // 底部标签，如 "睡眠"
    let progress: Double       // 0–1
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: max(0, min(1, progress)))
                    .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(value)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(.textPrimary)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: 50)
            }
            .frame(width: 64, height: 64)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 胶囊按钮。primary = 实心主色；否则浅底描边。
struct PillButton: View {
    let title: String
    var systemImage: String? = nil
    var filled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundColor(filled ? .white : .brandBlue)
            .background(filled ? Color.brandBlue : Color.brandBlue.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 趋势卡片统一规格（体重 / 睡眠 顶部趋势卡共用「父类」）
//
// 体重页与睡眠页最上方的趋势卡共享同一套外形规格：卡片高度、填充样式、内边距、
// 事件开关、图表区高度、底部图例带高度、事件点样式、时间过滤按钮。仅「图表内部画什么」
// 与配色不同——类似继承同一父类，子类只改内部数据与趋势样式。

/// 趋势卡统一尺寸常量。两页共用，改一处即可同时生效。
enum TrendCardSpec {
    /// 卡片内图表区固定高度（含加载 / 空态占位）：统一上下高度。
    static let chartHeight: CGFloat = 220
    /// 底部图例带固定高度：恒定预留，横滑 / 切 tab / 窗口内有无事件都不改变卡片高度。
    static let legendHeight: CGFloat = 18
    /// 事件点（菱形）边长：两图共用同一事件点样式。
    static let eventMarkSide: CGFloat = 10
}

/// 事件点统一样式：圆角方块旋转 45° 成菱形。供两张趋势图的 `.symbol { }` 复用。
struct EventMark: View {
    let color: Color
    var side: CGFloat = TrendCardSpec.eventMarkSide

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: side, height: side)
            .rotationEffect(.degrees(45))
    }
}

/// 趋势卡时间过滤按钮可承载的范围枚举：有分段标签、可遍历、可作选中态。
protocol TrendRange: Hashable, Identifiable, CaseIterable {
    var label: String { get }
}

/// 时间过滤按钮：统一分段控件样式，仅按页配色不同。
struct TrendRangePicker<Range: TrendRange>: View where Range.AllCases: RandomAccessCollection {
    @Binding var selection: Range
    let accent: Color
    var accessibilityLabel: String

    var body: some View {
        Picker("时间范围", selection: $selection) {
            ForEach(Range.allCases) { range in
                Text(range.label).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .tint(accent)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

/// 体重 / 睡眠顶部「趋势卡」统一容器（父类）：标题 + 事件开关 + 固定高度图表区 + 固定高度图例带。
/// 卡片高度、填充样式、内边距、事件开关、图表区高度、图例带高度全部统一；
/// 仅 `chart` 内部图形与 `accent` / `background` 配色不同。
struct TrendChartCard<ChartContent: View, LegendContent: View>: View {
    let title: String
    let accent: Color
    var background: Color
    @Binding var showsEvents: Bool
    let isLoading: Bool
    let isEmpty: Bool
    var emptyText: String
    @ViewBuilder var chart: () -> ChartContent
    @ViewBuilder var legend: () -> LegendContent

    var body: some View {
        CardView(background: background) {
            VStack(alignment: .leading, spacing: 12) {
                header
                chartArea
                legend()
                    // 不论窗口内是否有事件，图例带始终占住固定高度——横滑 / 切 tab 时卡片高度严格恒定。
                    .frame(maxWidth: .infinity,
                           minHeight: TrendCardSpec.legendHeight,
                           maxHeight: TrendCardSpec.legendHeight,
                           alignment: .leading)
            }
        }
    }

    private var header: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.textPrimary)
            Spacer()
            // 文字与开关同属一个 Toggle 标签，点击「事件」文字及其周围均可切换。
            Toggle(isOn: $showsEvents) {
                Text("事件")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .padding(.vertical, 6)
                    .padding(.trailing, 4)
                    .contentShape(Rectangle())
            }
            .tint(accent)
            .fixedSize()
            .accessibilityLabel("在图上显示事件")
        }
    }

    @ViewBuilder
    private var chartArea: some View {
        if isLoading && isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity,
                       minHeight: TrendCardSpec.chartHeight,
                       maxHeight: TrendCardSpec.chartHeight)
        } else if isEmpty {
            Text(emptyText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity,
                       minHeight: TrendCardSpec.chartHeight,
                       maxHeight: TrendCardSpec.chartHeight)
        } else {
            chart()
                .frame(height: TrendCardSpec.chartHeight)
        }
    }
}

/// 分区标题 + 可选右侧动作。
struct SectionTitle<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.textPrimary)
            Spacer()
            trailing
        }
    }
}

extension SectionTitle where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title: title) { EmptyView() }
    }
}
