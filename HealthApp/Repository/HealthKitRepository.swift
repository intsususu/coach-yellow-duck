// HealthKitRepository.swift
// HealthKit 只读数据源：体重、睡眠、运动能量与心率查询及聚合。PRD §7。

import Foundation
import HealthKit

final class HealthKitRepository: HealthDataRepository {
    private let healthStore: HKHealthStore
    private let eventRepository: HealthDataRepository
    private let calendar: Calendar

    init(healthStore: HKHealthStore = HKHealthStore(),
         eventRepository: HealthDataRepository,
         calendar: Calendar = .current) {
        self.healthStore = healthStore
        self.eventRepository = eventRepository
        self.calendar = calendar
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitRepositoryError.unavailable
        }
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    func homeRingMetrics() async -> HomeRingMetrics {
        async let sleep = todaySleepHours()
        async let rings = todayActivityRings()
        let (sleepHours, activity) = await (sleep, rings)
        return HomeRingMetrics(sleepHours: sleepHours,
                               sleepGoalHours: 8,
                               exerciseMinutes: activity.exerciseMinutes,
                               exerciseGoalMinutes: activity.exerciseGoalMinutes,
                               activeKcal: activity.activeKcal,
                               activeKcalGoal: activity.activeKcalGoal)
    }

    func sleepDurationTrend() async -> [DailyMetric] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -30, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)
        do {
            let nights = aggregateSleep(try await categorySamples(type: sleepType, predicate: predicate))
            return nights.map { DailyMetric(date: $0.date, value: $0.totalHours.rounded(toPlaces: 1)) }
        } catch {
            return []
        }
    }

    func activeEnergyTrend() async -> [DailyMetric] {
        guard let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return [] }
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -30, to: end) ?? end
        let anchor = calendar.startOfDay(for: start)
        var interval = DateComponents()
        interval.day = 1
        do {
            let buckets = try await statistics(type: energyType,
                                               options: .cumulativeSum,
                                               start: start,
                                               end: end,
                                               anchor: anchor,
                                               interval: interval)
            return buckets.compactMap { bucket in
                guard let kcal = bucket.statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) else { return nil }
                return DailyMetric(date: bucket.startDate, value: kcal.rounded())
            }
        } catch {
            return []
        }
    }

    func activeEnergyDailyTrend() async -> [DailyMetric] {
        guard let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return [] }
        let end = Date()
        let start = calendar.date(byAdding: .month, value: -6, to: end) ?? end
        let anchor = calendar.startOfDay(for: start)
        var interval = DateComponents()
        interval.day = 1
        do {
            // 按自然日累计全天活动消耗（与首页 activeEnergyTrend 同口径，跨度拉长到 6 个月）。
            let buckets = try await statistics(type: energyType,
                                               options: .cumulativeSum,
                                               start: start,
                                               end: end,
                                               anchor: anchor,
                                               interval: interval)
            return buckets.compactMap { bucket in
                guard let kcal = bucket.statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) else { return nil }
                return DailyMetric(date: bucket.startDate, value: kcal.rounded())
            }
        } catch {
            return []
        }
    }

    func basalEnergyDailyTrend() async -> [DailyMetric] {
        guard let energyType = HKObjectType.quantityType(forIdentifier: .basalEnergyBurned) else { return [] }
        let end = Date()
        let start = calendar.date(byAdding: .month, value: -6, to: end) ?? end
        let anchor = calendar.startOfDay(for: start)
        var interval = DateComponents()
        interval.day = 1
        do {
            // 按自然日累计静息（基础代谢）消耗；与活动消耗相加得到含静息代谢的总消耗。
            let buckets = try await statistics(type: energyType,
                                               options: .cumulativeSum,
                                               start: start,
                                               end: end,
                                               anchor: anchor,
                                               interval: interval)
            return buckets.compactMap { bucket in
                guard let kcal = bucket.statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) else { return nil }
                return DailyMetric(date: bucket.startDate, value: kcal.rounded())
            }
        } catch {
            return []
        }
    }

    func weightSeries(range: TimeRange) async -> [WeightSample] {
        guard let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return [] }
        let end = Date()
        let configuration = weightConfiguration(for: range, end: end)

        do {
            let buckets = try await statistics(type: bodyMass,
                                               options: .discreteAverage,
                                               start: configuration.start,
                                               end: end,
                                               anchor: configuration.anchor,
                                               interval: configuration.interval)
            let unit = HKUnit.gramUnit(with: .kilo)
            return buckets.compactMap { bucket in
                guard let value = bucket.statistics.averageQuantity()?.doubleValue(for: unit) else { return nil }
                return WeightSample(date: bucket.startDate, kg: value)
            }
        } catch {
            return []
        }
    }

    func bodyFatSeries(range: TimeRange) async -> [BodyFatSample] {
        guard let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass),
              let bodyFat = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) else { return [] }
        let end = Date()
        let configuration = weightConfiguration(for: range, end: end)
        let massUnit = HKUnit.gramUnit(with: .kilo)

        do {
            // 与体重序列同口径分桶：体脂率取均值，体脂肪质量 = 当桶体重均值 × 体脂率。
            async let massBuckets = statistics(type: bodyMass,
                                               options: .discreteAverage,
                                               start: configuration.start,
                                               end: end,
                                               anchor: configuration.anchor,
                                               interval: configuration.interval)
            async let fatBuckets = statistics(type: bodyFat,
                                              options: .discreteAverage,
                                              start: configuration.start,
                                              end: end,
                                              anchor: configuration.anchor,
                                              interval: configuration.interval)
            let (masses, fats) = try await (massBuckets, fatBuckets)
            let massByDate = Dictionary(uniqueKeysWithValues: masses.compactMap { bucket -> (Date, Double)? in
                guard let kg = bucket.statistics.averageQuantity()?.doubleValue(for: massUnit) else { return nil }
                return (bucket.startDate, kg)
            })
            return fats.compactMap { bucket in
                // HKUnit.percent() 返回 0~1 的分数。
                guard let fraction = bucket.statistics.averageQuantity()?.doubleValue(for: .percent()),
                      let kg = massByDate[bucket.startDate] else { return nil }
                return BodyFatSample(date: bucket.startDate,
                                     fatMassKg: (kg * fraction).rounded(toPlaces: 1),
                                     fatPercent: (fraction * 100).rounded(toPlaces: 1))
            }
        } catch {
            return []
        }
    }

    func recentWeightRecords(limit: Int) async -> [WeightSample] {
        guard let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return [] }
        let unit = HKUnit.gramUnit(with: .kilo)
        do {
            // 按测量结束时间降序取最近 N 条原始记录。
            let samples = try await quantitySamples(type: bodyMass, predicate: nil, limit: limit, ascending: false)
            return samples.map { WeightSample(date: $0.endDate, kg: $0.quantity.doubleValue(for: unit)) }
        } catch {
            return []
        }
    }

    func weightStatistics() async -> WeightStatistics {
        guard let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return WeightStatistics() }
        let unit = HKUnit.gramUnit(with: .kilo)
        let now = Date()
        let yearStart = calendar.date(from: DateComponents(year: calendar.component(.year, from: now),
                                                           month: 1, day: 1)) ?? now

        async let latest = quantitySamples(type: bodyMass, predicate: nil, limit: 1, ascending: false)
        async let yearStats = weightExtremes(type: bodyMass, start: yearStart, end: now, unit: unit)
        async let allStats = weightExtremes(type: bodyMass, start: Date.distantPast, end: now, unit: unit)

        let current = (try? await latest)?.first?.quantity.doubleValue(for: unit)
        let (yearLow, yearHigh) = (try? await yearStats) ?? (nil, nil)
        let (allLow, allHigh) = (try? await allStats) ?? (nil, nil)

        return WeightStatistics(
            current: current?.rounded(toPlaces: 1),
            yearHigh: yearHigh?.rounded(toPlaces: 1),
            yearLow: yearLow?.rounded(toPlaces: 1),
            allTimeHigh: allHigh?.rounded(toPlaces: 1),
            allTimeLow: allLow?.rounded(toPlaces: 1)
        )
    }

    func sleepSeries(range: TimeRange) async -> [SleepSample] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -sleepDayCount(for: range), to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)

        do {
            let samples = try await categorySamples(type: sleepType, predicate: predicate)
            return aggregateSleep(samples)
        } catch {
            return []
        }
    }

    func exerciseSeries(range: TimeRange) async -> [ExerciseSample] {
        guard let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return [] }

        let end = Date()
        let start = calendar.date(byAdding: .month, value: -23, to: end) ?? end
        let anchor = calendar.date(from: calendar.dateComponents([.year, .month], from: start)) ?? start
        var interval = DateComponents()
        interval.month = 1

        do {
            async let energyBuckets = statistics(type: energyType,
                                                  options: .cumulativeSum,
                                                  start: start,
                                                  end: end,
                                                  anchor: anchor,
                                                  interval: interval)
            async let heartBuckets = statistics(type: heartRateType,
                                                 options: .discreteAverage,
                                                 start: start,
                                                 end: end,
                                                 anchor: anchor,
                                                 interval: interval)
            let (energy, heartRate) = try await (energyBuckets, heartBuckets)
            let heartByMonth = Dictionary(uniqueKeysWithValues: heartRate.map {
                (monthKey($0.startDate), $0.statistics.averageQuantity()?.doubleValue(for: heartRateUnit))
            })
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M月"

            return energy.compactMap { bucket in
                guard let kcal = bucket.statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) else { return nil }
                return ExerciseSample(month: bucket.startDate,
                                      label: formatter.string(from: bucket.startDate),
                                      kcal: kcal,
                                      avgHR: heartByMonth[monthKey(bucket.startDate)] ?? nil,
                                      minutes: nil)
            }
        } catch {
            return []
        }
    }

    func workoutSessions() async -> [WorkoutSession] {
        let end = Date()
        // 取近 24 个月：供月度消耗「运动」口径回溯；统计卡仍按周期窗口（≤180 天）取近段。
        let start = calendar.date(byAdding: .month, value: -24, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        do {
            let workouts = try await workoutSamples(predicate: predicate)
            let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)
            return workouts.map { workout in
                let minutes = Int((workout.duration / 60).rounded())
                let kcal = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
                let avgHR = heartRateType.flatMap {
                    workout.statistics(for: $0)?.averageQuantity()?.doubleValue(for: heartRateUnit)
                }
                return WorkoutSession(start: workout.startDate,
                                      type: workoutKind(for: workout.workoutActivityType),
                                      minutes: minutes,
                                      kcal: kcal.rounded(),
                                      avgHR: avgHR.map { $0.rounded() })
            }
        } catch {
            return []
        }
    }

    // T08 被跳过时，事件继续委托给现有内存仓库；后续可无缝替换为 EventStore。
    func events() async -> [HealthEvent] {
        await eventRepository.events()
    }

    func saveEvent(_ event: HealthEvent) async {
        await eventRepository.saveEvent(event)
    }

    func deleteEvent(_ event: HealthEvent) async {
        await eventRepository.deleteEvent(event)
    }
}

private extension HealthKitRepository {
    struct StatisticsBucket {
        let startDate: Date
        let statistics: HKStatistics
    }

    struct WeightQueryConfiguration {
        let start: Date
        let anchor: Date
        let interval: DateComponents
    }

    struct SleepAccumulator {
        var deep = 0
        var core = 0
        var rem = 0
        var awake = 0
        var unspecified = 0
        var bedtime: Date?   // 当晚最早一段睡眠的开始时刻
        var wakeTime: Date?  // 当晚最晚一段睡眠的结束时刻
    }

    struct ActivityRingValues {
        var exerciseMinutes: Int
        var exerciseGoalMinutes: Int
        var activeKcal: Int
        var activeKcalGoal: Int

        /// 无活动摘要（未戴表 / 未授权）时的兜底：值为 0，目标取 Apple 常见默认。
        static let fallback = ActivityRingValues(exerciseMinutes: 0, exerciseGoalMinutes: 30,
                                                 activeKcal: 0, activeKcalGoal: 500)
    }

    var readTypes: Set<HKObjectType> {
        let identifiers: [HKQuantityTypeIdentifier] = [
            .bodyMass,
            .bodyFatPercentage,
            .activeEnergyBurned,
            .basalEnergyBurned,
            .appleExerciseTime,
            .heartRate,
        ]
        var types = Set(identifiers.compactMap { HKObjectType.quantityType(forIdentifier: $0) as HKObjectType? })
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        types.insert(HKObjectType.workoutType())
        types.insert(HKObjectType.activitySummaryType())  // 读取活动环数值与目标
        return types
    }

    /// 当日睡眠时长（小时）：取最近一晚 sleepAnalysis 聚合的总时长。
    func todaySleepHours() async -> Double {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -2, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)
        do {
            let nights = aggregateSleep(try await categorySamples(type: sleepType, predicate: predicate))
            guard let latest = nights.last else { return 0 }
            return (Double(latest.totalMinutes) / 60.0).rounded(toPlaces: 1)
        } catch {
            return 0
        }
    }

    /// 当日活动环：锻炼分钟 / 活动热量及各自目标，取自 HKActivitySummary。
    func todayActivityRings() async -> ActivityRingValues {
        guard let summary = await todayActivitySummary() else { return .fallback }
        let exercise = Int(summary.appleExerciseTime.doubleValue(for: .minute()).rounded())
        let kcal = Int(summary.activeEnergyBurned.doubleValue(for: .kilocalorie()).rounded())
        // 目标均为非可选 HKQuantity；未设置活动目标时读到 0，故用 > 0 兜底。
        let exerciseGoal = Int(summary.appleExerciseTimeGoal.doubleValue(for: .minute()).rounded())
        let kcalGoal = Int(summary.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie()).rounded())
        return ActivityRingValues(
            exerciseMinutes: exercise,
            exerciseGoalMinutes: exerciseGoal > 0 ? exerciseGoal : ActivityRingValues.fallback.exerciseGoalMinutes,
            activeKcal: kcal,
            activeKcalGoal: kcalGoal > 0 ? kcalGoal : ActivityRingValues.fallback.activeKcalGoal
        )
    }

    /// 查询当日活动摘要（HKActivitySummary 携带锻炼/热量的值与目标）。
    func todayActivitySummary() async -> HKActivitySummary? {
        await withCheckedContinuation { continuation in
            var components = calendar.dateComponents([.year, .month, .day], from: Date())
            components.calendar = calendar
            let predicate = HKQuery.predicate(forActivitySummariesBetweenStart: components, end: components)
            let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, _ in
                continuation.resume(returning: summaries?.last)
            }
            healthStore.execute(query)
        }
    }

    var heartRateUnit: HKUnit {
        HKUnit.count().unitDivided(by: .minute())
    }

    func weightConfiguration(for range: TimeRange, end: Date) -> WeightQueryConfiguration {
        var interval = DateComponents()
        let start: Date

        switch range {
        // 周 / 月：日级分桶，由趋势图按 7 天 / 30 天窗口滑动取景。
        case .week:
            interval.day = 1
            start = calendar.date(byAdding: .weekOfYear, value: -12, to: end) ?? end
        case .month:
            interval.day = 1
            start = calendar.date(byAdding: .month, value: -12, to: end) ?? end
        // 年：月级分桶，按 12 个月窗口滑动。
        case .year:
            interval.month = 1
            start = calendar.date(byAdding: .year, value: -3, to: end) ?? end
        case .all:
            interval.year = 1
            start = calendar.date(from: DateComponents(year: 2019, month: 1, day: 1)) ?? end
        }

        let anchor = calendar.date(from: calendar.dateComponents([.year, .month, .weekOfYear], from: start)) ?? start
        return WeightQueryConfiguration(start: start, anchor: anchor, interval: interval)
    }

    func sleepDayCount(for range: TimeRange) -> Int {
        // 取数刻意超出可视窗口，留足屏幕外历史供趋势图横向滑动（与体重图同策略）：
        // 周窗口 6 天取近 12 周、月窗口 29 天取近 12 个月；6 个月（year）聚合周均需整年日级数据。
        switch range {
        case .week: return 12 * 7
        case .month: return 365
        case .year, .all: return 365
        }
    }

    func statistics(type: HKQuantityType,
                    options: HKStatisticsOptions,
                    start: Date,
                    end: Date,
                    anchor: Date,
                    interval: DateComponents) async throws -> [StatisticsBucket] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKStatisticsCollectionQuery(quantityType: type,
                                                    quantitySamplePredicate: predicate,
                                                    options: options,
                                                    anchorDate: anchor,
                                                    intervalComponents: interval)
            query.initialResultsHandler = { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result else {
                    continuation.resume(returning: [])
                    return
                }
                var buckets: [StatisticsBucket] = []
                result.enumerateStatistics(from: start, to: end) { statistics, _ in
                    buckets.append(StatisticsBucket(startDate: statistics.startDate,
                                                     statistics: statistics))
                }
                continuation.resume(returning: buckets)
            }
            healthStore.execute(query)
        }
    }

    /// 原始数值样本查询（按 endDate 排序，可限制条数）。
    func quantitySamples(type: HKQuantityType,
                         predicate: NSPredicate?,
                         limit: Int,
                         ascending: Bool) async throws -> [HKQuantitySample] {
        try await withCheckedThrowingContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: ascending)
            let query = HKSampleQuery(sampleType: type,
                                      predicate: predicate,
                                      limit: limit,
                                      sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
            }
            healthStore.execute(query)
        }
    }

    /// 区间内体重最小 / 最大值（kg），通过单次离散统计查询一并取回。
    func weightExtremes(type: HKQuantityType,
                        start: Date,
                        end: Date,
                        unit: HKUnit) async throws -> (min: Double?, max: Double?) {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKStatisticsQuery(quantityType: type,
                                          quantitySamplePredicate: predicate,
                                          options: [.discreteMin, .discreteMax]) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let minValue = statistics?.minimumQuantity()?.doubleValue(for: unit)
                let maxValue = statistics?.maximumQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: (minValue, maxValue))
            }
            healthStore.execute(query)
        }
    }

    /// 按次锻炼查询（HKWorkout，按开始时间升序）。
    func workoutSamples(predicate: NSPredicate) async throws -> [HKWorkout] {
        try await withCheckedThrowingContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: .workoutType(),
                                      predicate: predicate,
                                      limit: HKObjectQueryNoLimit,
                                      sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples as? [HKWorkout] ?? [])
            }
            healthStore.execute(query)
        }
    }

    /// HealthKit 锻炼类型 → 应用内运动类型分桶（占比 / 图标用）。
    func workoutKind(for type: HKWorkoutActivityType) -> WorkoutKind {
        switch type {
        case .running, .trackAndField:
            return .running
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining, .crossTraining:
            return .strength
        case .cycling, .handCycling:
            return .cycling
        case .swimming, .swimBikeRun, .waterFitness:
            return .swimming
        case .walking, .hiking:
            return .walking
        case .yoga, .pilates, .flexibility, .mindAndBody:
            return .yoga
        default:
            return .running   // 未细分的有氧统一归「跑步」桶
        }
    }

    func categorySamples(type: HKCategoryType,
                         predicate: NSPredicate) async throws -> [HKCategorySample] {
        try await withCheckedThrowingContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
            let query = HKSampleQuery(sampleType: type,
                                      predicate: predicate,
                                      limit: HKObjectQueryNoLimit,
                                      sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples as? [HKCategorySample] ?? [])
            }
            healthStore.execute(query)
        }
    }

    func aggregateSleep(_ samples: [HKCategorySample]) -> [SleepSample] {
        var nights: [Date: SleepAccumulator] = [:]

        for sample in samples {
            let shiftedEnd = sample.endDate.addingTimeInterval(-12 * 60 * 60)
            let night = calendar.startOfDay(for: shiftedEnd)
            let minutes = max(0, Int(sample.endDate.timeIntervalSince(sample.startDate) / 60))
            var accumulator = nights[night] ?? SleepAccumulator()

            var isAsleep = true
            switch sample.value {
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                accumulator.deep += minutes
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                accumulator.core += minutes
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                accumulator.rem += minutes
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                accumulator.awake += minutes
                isAsleep = false
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                accumulator.unspecified += minutes
            default:
                isAsleep = false
            }
            // 入睡 / 起床时刻取实际睡着段的最早开始与最晚结束（清醒、在床等不计入）。
            if isAsleep {
                accumulator.bedtime = min(accumulator.bedtime ?? sample.startDate, sample.startDate)
                accumulator.wakeTime = max(accumulator.wakeTime ?? sample.endDate, sample.endDate)
            }
            nights[night] = accumulator
        }

        return nights.keys.sorted().compactMap { date in
            guard let value = nights[date] else { return nil }
            let total = value.deep + value.core + value.rem + value.unspecified
            guard total > 0 else { return nil }
            let timeInBed = total + value.awake
            let efficiency = timeInBed > 0 ? Double(total) / Double(timeInBed) : nil
            return SleepSample(date: date,
                               totalMinutes: total,
                               deepMinutes: value.deep,
                               coreMinutes: value.core + value.unspecified,
                               remMinutes: value.rem,
                               awakeMinutes: value.awake,
                               efficiency: efficiency,
                               bedtime: value.bedtime,
                               wakeTime: value.wakeTime)
        }
    }

    func monthKey(_ date: Date) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)"
    }
}

enum HealthKitRepositoryError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable: return "此设备不支持 Apple 健康数据。"
        }
    }
}
