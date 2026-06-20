// EventStore.swift
// 事件本机持久化（UserDefaults + JSON 编码）。PRD §6.1 / T08。
// 调试构建以 PRD §6.2 的 4 条 mock 作为种子；用户新建/编辑的事件重启后仍在。
// 事件不依赖 HealthKit：调试走 MockHealthRepository、正式走 EventRepository，二者都通过它读写。

import Foundation

final class EventStore {
    private let userDefaults: UserDefaults
    private let storageKey: String
    private let seed: [HealthEvent]

    init(userDefaults: UserDefaults = .standard,
         storageKey: String = "com.xltc.sdlyc.events.v1",
         seed: [HealthEvent] = EventStore.defaultSeed) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.seed = seed
    }

    /// 读取全部事件；首次启动落种子，保证初始 4 条存在。
    func load() -> [HealthEvent] {
        guard let data = userDefaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([HealthEvent].self, from: data) else {
            persist(seed)
            return seed
        }
        return decoded
    }

    /// 新增或更新（按 id）：已存在则原地替换，否则插入顶部。返回更新后的全集。
    @discardableResult
    func upsert(_ event: HealthEvent) -> [HealthEvent] {
        var events = load()
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
        } else {
            events.insert(event, at: 0)
        }
        persist(events)
        return events
    }

    /// 按 id 删除一条事件。返回删除后的全集。
    @discardableResult
    func delete(_ event: HealthEvent) -> [HealthEvent] {
        var events = load()
        events.removeAll { $0.id == event.id }
        persist(events)
        return events
    }

    private func persist(_ events: [HealthEvent]) {
        guard let data = try? JSONEncoder().encode(events) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}

/// 正式（真机）构建的事件仓库：仅负责事件的本机持久化，不含任何 mock 健康数据。
/// 健康指标在真机由 `HealthKitRepository` 提供，本类型的指标方法仅作协议占位返回空值
///（`HealthKitRepository` 会覆盖全部指标读取，只把事件读写委托到这里）。
/// 初始不落任何示例事件（seed 为空），用户从空列表开始记录，确保正式使用不出现 mock。
final class EventRepository: HealthDataRepository {
    private let eventStore: EventStore

    init(eventStore: EventStore = EventStore(seed: [])) {
        self.eventStore = eventStore
    }

    // MARK: - 指标方法（真机由 HealthKitRepository 覆盖，这里仅占位）
    func requestAuthorization() async throws { }
    func homeRingMetrics() async -> HomeRingMetrics { .empty }
    func sleepDurationTrend() async -> [DailyMetric] { [] }
    func activeEnergyTrend() async -> [DailyMetric] { [] }
    func activeEnergyDailyTrend() async -> [DailyMetric] { [] }
    func basalEnergyDailyTrend() async -> [DailyMetric] { [] }
    func weightSeries(range: TimeRange) async -> [WeightSample] { [] }
    func recentWeightRecords(limit: Int) async -> [WeightSample] { [] }
    func weightStatistics() async -> WeightStatistics { WeightStatistics() }
    func sleepSeries(range: TimeRange) async -> [SleepSample] { [] }
    func exerciseSeries(range: TimeRange) async -> [ExerciseSample] { [] }
    func workoutSessions() async -> [WorkoutSession] { [] }

    // MARK: - 事件读写（本机持久化）
    func events() async -> [HealthEvent] { eventStore.load() }
    func saveEvent(_ event: HealthEvent) async { eventStore.upsert(event) }
    func deleteEvent(_ event: HealthEvent) async { eventStore.delete(event) }
}

extension EventStore {
    /// 初始 4 条事件（原样取自 PRD §6.2）。
    static let defaultSeed: [HealthEvent] = [
        HealthEvent(id: "e1", type: .travel,  title: "出差 · 上海",
                    startDate: HealthEvent.date("2026-06-10"), endDate: HealthEvent.date("2026-06-14"),
                    note: "作息紊乱，运动暂停"),
        HealthEvent(id: "e2", type: .drink,   title: "饮酒 · 聚餐",
                    startDate: HealthEvent.date("2026-06-07"), endDate: nil,
                    note: "深睡下降，效率降到 88%"),
        HealthEvent(id: "e3", type: .illness, title: "感冒发烧",
                    startDate: HealthEvent.date("2026-05-31"), endDate: nil,
                    note: "已就医，停训一周，体重回升 0.6kg"),
        HealthEvent(id: "e4", type: .illness, title: "腰肌肉拉伤",
                    startDate: HealthEvent.date("2026-05-20"), endDate: HealthEvent.date("2026-05-27"),
                    note: "停训一周，周消耗降到平时 1/3"),
    ]
}
