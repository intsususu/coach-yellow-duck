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
        let start = calendar.date(byAdding: .month, value: -6, to: end) ?? end
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
                return ExerciseSample(label: formatter.string(from: bucket.startDate),
                                      kcal: kcal,
                                      avgHR: heartByMonth[monthKey(bucket.startDate)] ?? nil,
                                      minutes: nil)
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
    }

    var readTypes: Set<HKObjectType> {
        let identifiers: [HKQuantityTypeIdentifier] = [
            .bodyMass,
            .activeEnergyBurned,
            .appleExerciseTime,
            .heartRate,
        ]
        var types = Set(identifiers.compactMap { HKObjectType.quantityType(forIdentifier: $0) as HKObjectType? })
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        types.insert(HKObjectType.workoutType())
        return types
    }

    var heartRateUnit: HKUnit {
        HKUnit.count().unitDivided(by: .minute())
    }

    func weightConfiguration(for range: TimeRange, end: Date) -> WeightQueryConfiguration {
        var interval = DateComponents()
        let start: Date

        switch range {
        case .week:
            interval.weekOfYear = 1
            start = calendar.date(byAdding: .weekOfYear, value: -26, to: end) ?? end
        case .month:
            interval.month = 1
            start = calendar.date(byAdding: .month, value: -12, to: end) ?? end
        case .year, .all:
            interval.year = 1
            start = calendar.date(from: DateComponents(year: 2019, month: 1, day: 1)) ?? end
        }

        let anchor = calendar.date(from: calendar.dateComponents([.year, .month, .weekOfYear], from: start)) ?? start
        return WeightQueryConfiguration(start: start, anchor: anchor, interval: interval)
    }

    func sleepDayCount(for range: TimeRange) -> Int {
        switch range {
        case .week: return 7
        case .month: return 30
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

            switch sample.value {
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                accumulator.deep += minutes
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                accumulator.core += minutes
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                accumulator.rem += minutes
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                accumulator.awake += minutes
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                accumulator.unspecified += minutes
            default:
                break
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
                               efficiency: efficiency)
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
