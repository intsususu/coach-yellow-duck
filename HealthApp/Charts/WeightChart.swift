// WeightChart.swift
// 可复用体重折线图：趋势、目标线、单日事件点与时间段色带。

import Charts
import SwiftUI

struct WeightChart: View {
    let samples: [WeightSample]
    let goalWeight: Double
    let events: [HealthEvent]
    let showsEvents: Bool
    let range: TimeRange

    private var sortedSamples: [WeightSample] {
        samples.sorted { $0.date < $1.date }
    }

    private var visibleEvents: [HealthEvent] {
        guard let first = sortedSamples.first?.date, let last = sortedSamples.last?.date else { return [] }
        return events.filter { event in
            let eventEnd = event.endDate ?? event.startDate
            return event.startDate <= last && eventEnd >= first
        }
    }

    private var yDomain: ClosedRange<Double> {
        let values = sortedSamples.map(\.kg) + [goalWeight]
        let minimum = values.min() ?? goalWeight
        let maximum = values.max() ?? goalWeight
        let padding = max((maximum - minimum) * 0.18, 1.0)
        return (minimum - padding)...(maximum + padding)
    }

    var body: some View {
        Chart {
            if showsEvents {
                ForEach(visibleEvents.filter(\.isPeriod)) { event in
                    RectangleMark(
                        xStart: .value("事件开始", event.startDate),
                        xEnd: .value("事件结束", event.endDate ?? event.startDate),
                        yStart: .value("下界", yDomain.lowerBound),
                        yEnd: .value("上界", yDomain.upperBound)
                    )
                    .foregroundStyle(event.type.backgroundColor.opacity(0.7))
                }
            }

            ForEach(sortedSamples) { sample in
                AreaMark(
                    x: .value("日期", sample.date),
                    yStart: .value("基线", yDomain.lowerBound),
                    yEnd: .value("体重", sample.kg)
                )
                .foregroundStyle(
                    LinearGradient(colors: [.brandBlue.opacity(0.24), .brandBlue.opacity(0.01)],
                                   startPoint: .top,
                                   endPoint: .bottom)
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("日期", sample.date),
                    y: .value("体重", sample.kg)
                )
                .foregroundStyle(Color.brandBlue)
                .lineStyle(StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }

            RuleMark(y: .value("目标", goalWeight))
                .foregroundStyle(Color.exerciseOrange)
                .lineStyle(StrokeStyle(lineWidth: 1.4, dash: [5, 4]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("目标 \(String(format: "%.0f", goalWeight))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.exerciseOrange)
                }

            if let last = sortedSamples.last {
                PointMark(x: .value("日期", last.date), y: .value("体重", last.kg))
                    .foregroundStyle(Color.brandBlue)
                    .symbolSize(55)
            }

            if showsEvents {
                ForEach(visibleEvents.filter { !$0.isPeriod }) { event in
                    PointMark(
                        x: .value("事件日期", event.startDate),
                        y: .value("事件体重", nearestWeight(to: event.startDate))
                    )
                    .foregroundStyle(event.type.color)
                    .symbol {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(event.type.color)
                            .frame(width: 10, height: 10)
                            .rotationEffect(.degrees(45))
                    }
                }
            }
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color.hairline)
                AxisValueLabel {
                    if let weight = value.as(Double.self) {
                        Text(String(format: "%.0f", weight))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.textMuted)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(axisLabel(for: date))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.textMuted)
                    }
                }
            }
        }
        .accessibilityLabel("体重趋势图")
    }

    private func nearestWeight(to date: Date) -> Double {
        sortedSamples.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }?.kg ?? yDomain.upperBound
    }

    private func axisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = range == .year || range == .all ? "yyyy" : "M月"
        return formatter.string(from: date)
    }
}
