// BodyFatChart.swift
// 体脂单序列折线图：体脂肪（kg）或体脂率（%）各用一张，互不叠加。
// 仿体重图：固定宽度可视窗口随手势横向滑动；不叠加事件。体脂变化小，故卡片高度更矮。

import Charts
import SwiftUI

struct BodyFatChart: View {
    let samples: [BodyFatSample]
    /// 取值闭包：体脂肪（fatMassKg）或体脂率（fatPercent）。
    let value: (BodyFatSample) -> Double
    let range: TimeRange
    /// 可视窗口前沿（leading edge）。为 nil 时（「全部」）一次展示全部数据。
    @Binding var scrollPosition: Date
    /// 线条与轴标签配色（粉色系）。
    var color: Color
    /// 是否虚线（体脂率用虚线，体脂肪用实线）。
    var dashed: Bool
    /// Y 轴标签格式（如 "%.1f" / "%.1f%%"）。
    var valueFormat: String

    private var sortedSamples: [BodyFatSample] {
        samples.sorted { $0.date < $1.date }
    }

    /// 当前可视窗口区间；「全部」覆盖整段数据。
    private var visibleWindow: ClosedRange<Date> {
        guard let seconds = range.visibleDomainSeconds else {
            let first = sortedSamples.first?.date ?? Date()
            let last = sortedSamples.last?.date ?? Date()
            return first...max(first, last)
        }
        return scrollPosition...scrollPosition.addingTimeInterval(seconds)
    }

    /// 绘图域右侧留白：让最后一个圆点离开裁剪边界（与体重图同比例）。
    private var trailingPadSeconds: Double {
        if let seconds = range.visibleDomainSeconds { return seconds * WeightChart.trailingPadFactor }
        let first = sortedSamples.first?.date ?? Date()
        let last = sortedSamples.last?.date ?? Date()
        return max(last.timeIntervalSince(first) * WeightChart.trailingPadFactor, 86_400)
    }

    /// Y 轴自适应当前窗口内的样本（滑动时纵向重新取景，仿体重图）。
    private var yDomain: ClosedRange<Double> {
        let window = visibleWindow
        let inside = sortedSamples.filter { window.contains($0.date) }
        let base = inside.isEmpty ? sortedSamples : inside
        let values = base.map(value)
        let minimum = values.min() ?? 0
        let maximum = values.max() ?? 1
        // 体脂变化小，留白取相对值并设较小下限，保证趋势起伏可见。
        let padding = max((maximum - minimum) * 0.2, 0.3)
        return (minimum - padding)...(maximum + padding)
    }

    var body: some View {
        scrollable(
            Chart {
                ForEach(sortedSamples) { sample in
                    LineMark(
                        x: .value("日期", sample.date),
                        y: .value("体脂", value(sample))
                    )
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round,
                                           dash: dashed ? [5, 3] : []))
                    .interpolationMethod(.catmullRom)
                }

                if let last = sortedSamples.last {
                    PointMark(x: .value("日期", last.date), y: .value("体脂", value(last)))
                        .foregroundStyle(color)
                        .symbolSize(45)

                    // 末尾留白锚点：把绘图域向右撑出一点，避免最后一个圆点贴边被裁。
                    PointMark(x: .value("末尾留白", last.date.addingTimeInterval(trailingPadSeconds)),
                              y: .value("体脂", value(last)))
                        .foregroundStyle(.clear)
                        .symbolSize(0)
                }
            }
            .chartYScale(domain: yDomain)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { axisValue in
                    AxisGridLine().foregroundStyle(Color.hairline)
                    AxisValueLabel {
                        if let v = axisValue.as(Double.self) {
                            Text(String(format: valueFormat, v))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(color)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: axisStride) { axisValue in
                    AxisGridLine().foregroundStyle(Color.hairline)
                    AxisValueLabel {
                        if let date = axisValue.as(Date.self) {
                            Text(axisLabel(for: date))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.textMuted)
                        }
                    }
                }
            }
            .accessibilityLabel("体脂趋势图")
        )
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
        case .week:  return .stride(by: .day)
        case .month: return .stride(by: .day, count: 7)
        case .year:  return .stride(by: .month)
        case .all:   return .stride(by: .year)
        }
    }

    private func axisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        switch range {
        case .week:  formatter.dateFormat = "EEE"
        case .month: formatter.dateFormat = "d日"
        case .year:  formatter.dateFormat = "M月"
        case .all:   formatter.dateFormat = "yyyy"
        }
        return formatter.string(from: date)
    }
}
