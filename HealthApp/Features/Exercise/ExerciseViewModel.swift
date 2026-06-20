// ExerciseViewModel.swift
// 运动页数据缓存：首次进入读取 HealthKit，Tab 往返与范围切换复用已加载结果。

import Foundation

@MainActor
final class ExerciseViewModel: ObservableObject {
    @Published private(set) var exerciseDaily: [DailyMetric] = []
    @Published private(set) var basalDaily: [DailyMetric] = []
    @Published private(set) var monthlySamples: [ExerciseSample] = []
    @Published private(set) var workouts: [WorkoutSession] = []
    @Published private(set) var isDailyLoading = false
    @Published private(set) var isMonthlyLoading = false

    private var hasLoadedDaily = false
    private var hasLoadedMonthly = false

    func loadDailyIfNeeded(from repository: HealthDataRepository) async {
        guard !hasLoadedDaily else { return }
        hasLoadedDaily = true
        isDailyLoading = true

        async let active = repository.activeEnergyDailyTrend()
        async let basal = repository.basalEnergyDailyTrend()
        (exerciseDaily, basalDaily) = await (active, basal)

        isDailyLoading = false
    }

    func loadMonthlyIfNeeded(from repository: HealthDataRepository) async {
        guard !hasLoadedMonthly else { return }
        hasLoadedMonthly = true
        isMonthlyLoading = true

        async let monthly = repository.exerciseSeries(range: .all)
        async let sessions = repository.workoutSessions()
        (monthlySamples, workouts) = await (monthly, sessions)

        isMonthlyLoading = false
    }
}
