// WeightViewModel.swift
// 体重页数据加载与派生统计。

import Foundation

@MainActor
final class WeightViewModel: ObservableObject {
    @Published private(set) var samples: [WeightSample] = []
    @Published private(set) var weeklySamples: [WeightSample] = []
    @Published private(set) var isLoading = false

    func loadInitialData(from repository: HealthDataRepository) async {
        guard weeklySamples.isEmpty else { return }
        weeklySamples = await repository.weightSeries(range: .week)
    }

    func loadSeries(for range: TimeRange, from repository: HealthDataRepository) async {
        isLoading = true
        samples = await repository.weightSeries(range: range)
        if range == .week {
            weeklySamples = samples
        }
        isLoading = false
    }

    var recentRecords: [WeightSample] {
        Array(weeklySamples.suffix(5).reversed())
    }

    var currentWeight: Double? {
        weeklySamples.last?.kg.rounded(toPlaces: 1)
    }

    var cumulativeChange: Double? {
        guard let currentWeight else { return nil }
        return (currentWeight - WeightHistoryContract.startWeight).rounded(toPlaces: 1)
    }

    var historicalLow: Double? {
        guard !weeklySamples.isEmpty else { return nil }
        return min(weeklySamples.map(\.kg).min() ?? WeightHistoryContract.historicalLow,
                   WeightHistoryContract.historicalLow)
    }

    var historicalHigh: Double? {
        guard !weeklySamples.isEmpty else { return nil }
        return max(weeklySamples.map(\.kg).max() ?? WeightHistoryContract.startWeight,
                   WeightHistoryContract.startWeight)
    }
}

private enum WeightHistoryContract {
    // 高保真原型的完整历史边界；§6.2 仅提供图表聚合子集。
    static let startWeight = 91.2
    static let historicalLow = 71.9
}
