// WeightViewModel.swift
// 体重页数据加载与派生统计。

import Foundation

@MainActor
final class WeightViewModel: ObservableObject {
    @Published private(set) var samples: [WeightSample] = []
    @Published private(set) var recentRecords: [WeightSample] = []
    @Published private(set) var statistics = WeightStatistics()
    @Published private(set) var isLoading = false

    private var hasLoadedSummary = false
    private var seriesRequestID: UUID?

    func loadInitialData(from repository: HealthDataRepository,
                         forceReload: Bool = false) async {
        guard forceReload || !hasLoadedSummary else { return }
        hasLoadedSummary = true
        async let records = repository.recentWeightRecords(limit: 5)
        async let stats = repository.weightStatistics()
        (recentRecords, statistics) = await (records, stats)
    }

    /// 只允许最新的范围请求提交数据，避免快速切换时旧请求覆盖新图表。
    @discardableResult
    func loadSeries(for range: TimeRange, from repository: HealthDataRepository) async -> Bool {
        let requestID = UUID()
        seriesRequestID = requestID
        isLoading = true
        let loadedSamples = await repository.weightSeries(range: range)

        guard !Task.isCancelled, seriesRequestID == requestID else {
            if seriesRequestID == requestID { isLoading = false }
            return false
        }
        samples = loadedSamples
        isLoading = false
        return true
    }
}
