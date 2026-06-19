// ExerciseChart.swift
// 六个月运动柱状图，支持千卡 / 心率切换与损伤事件标记。

import Charts
import SwiftUI

struct ExerciseChart: View {
    let samples: [ExerciseSample]
    let metric: ExerciseMetric
    let events: [HealthEvent]

    private var color: Color {
        metric == .kcal ? .exerciseOrange : .eventTravel
    }

    var body: some View {
        Chart {
            ForEach(samples) { sample in
                BarMark(
                    x: .value("月份", sample.label),
                    y: .value(metric.title, value(for: sample))
                )
                .foregroundStyle(color)
                .cornerRadius(5)
            }

            ForEach(injuryEvents) { event in
                if let sample = sample(for: event) {
                    PointMark(
                        x: .value("损伤月份", sample.label),
                        y: .value("事件位置", value(for: sample) * 1.06)
                    )
                    .foregroundStyle(Color.eventInjury)
                    .symbol {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.eventInjury)
                            .frame(width: 10, height: 10)
                            .rotationEffect(.degrees(45))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color.hairline)
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(axisValue(number))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.textMuted)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.textMuted)
            }
        }
        .accessibilityLabel(metric == .kcal ? "月度运动消耗" : "月度平均心率")
    }

    private var injuryEvents: [HealthEvent] {
        events.filter { $0.type == .injury }
    }

    private func value(for sample: ExerciseSample) -> Double {
        metric == .kcal ? sample.kcal : (sample.avgHR ?? 0)
    }

    private func sample(for event: HealthEvent) -> ExerciseSample? {
        let month = Calendar.current.component(.month, from: event.startDate)
        return samples.first { $0.label == "\(month)月" }
    }

    private func axisValue(_ value: Double) -> String {
        if metric == .heartRate { return String(format: "%.0f", value) }
        return value >= 1_000 ? String(format: "%.0fk", value / 1_000) : String(format: "%.0f", value)
    }
}
