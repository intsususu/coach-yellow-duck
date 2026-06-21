// AnalysisViewModel.swift
// 通过 HealthDataRepository 统一加载分析所需数据，视图不直接感知具体数据源。

import Foundation

@MainActor
final class AnalysisViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var latestDataDate: Date?
    @Published private(set) var errorMessage: String?

    private let repository: HealthDataRepository
    private var weights: [WeightSample] = []
    private var sleeps: [SleepSample] = []
    private var workouts: [WorkoutSession] = []

    init(repository: HealthDataRepository) {
        self.repository = repository
    }

    func prepare() async {
        guard weights.isEmpty && sleeps.isEmpty && workouts.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        async let weightResult = repository.weightSeries(range: .month)
        async let sleepResult = repository.sleepSeries(range: .month)
        async let workoutResult = repository.workoutSessions()
        let (weights, sleeps, workouts) = await (weightResult, sleepResult, workoutResult)

        self.weights = weights
        self.sleeps = sleeps
        self.workouts = workouts
        latestDataDate = [weights.map(\.date).max(), sleeps.map(\.date).max(), workouts.map(\.start).max()]
            .compactMap { $0 }
            .max()
        if latestDataDate == nil {
            errorMessage = "暂无可用于分析的数据"
        }
        isLoading = false
    }

    func dataDayCount(from startDate: Date, to endDate: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
        let days = weights.filter { $0.date >= start && $0.date < end }.map { calendar.startOfDay(for: $0.date) }
            + sleeps.filter { $0.date >= start && $0.date < end }.map { calendar.startOfDay(for: $0.date) }
            + workouts.filter { $0.start >= start && $0.start < end }.map { calendar.startOfDay(for: $0.start) }
        return Set(days).count
    }

    func makeReport(startDate: Date,
                    endDate: Date,
                    events: [HealthEvent],
                    goalWeight: Double) -> AnalysisReport {
        AnalysisReportEngine().makeReport(weights: weights,
                                          sleeps: sleeps,
                                          workouts: workouts,
                                          events: events,
                                          goalWeight: goalWeight,
                                          startDate: startDate,
                                          endDate: endDate)
    }
}
