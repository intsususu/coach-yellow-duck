// WeightSparkline.swift
// 首页体重 Hero 卡的最近 30 日趋势小折线（静态，无坐标轴）。复用 MetricSparkline。

import SwiftUI

struct WeightSparkline: View {
    let samples: [WeightSample]

    var body: some View {
        MetricSparkline(
            points: samples.map { DailyMetric(date: $0.date, value: $0.kg) },
            color: .weightGreen
        )
    }
}
