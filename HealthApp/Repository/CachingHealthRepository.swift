// CachingHealthRepository.swift
// 趋势数据缓存装饰器：包裹真实数据源（Mock / HealthKit），为运动 / 体重 / 睡眠页提供
//   · 启动预热（prewarm）：splash 期间并行拉好各 tab 首屏数据，点开即有、不再转圈；
//   · 本地快照（snapshot）：每次结果落盘，下次冷启动先用上次数据秒开，再由预热刷新覆盖；
//   · 在途去重（in-flight dedup）：同一查询并发命中时复用同一个 Task，避免重复打 HealthKit。
// 视图层无需改动——仍只依赖 HealthDataRepository 协议，仓库被本类透明包裹。

import Foundation

// MARK: - 本地快照

/// 各趋势页最近一次成功加载的结果。冷启动时回灌，避免空屏 / 转圈。
/// 数组型字段按 `TimeRange.rawValue` 分桶，便于按页面所需范围分别缓存。
private struct TrendSnapshot: Codable {
    var activeEnergyDaily: [DailyMetric] = []
    var basalEnergyDaily: [DailyMetric] = []
    var exerciseSeries: [String: [ExerciseSample]] = [:]
    var workouts: [WorkoutSession] = []
    var weightSeries: [String: [WeightSample]] = [:]
    var bodyFatSeries: [String: [BodyFatSample]] = [:]
    var recentWeight: [WeightSample] = []
    var weightStatistics = WeightStatistics()
    var sleepSeries: [String: [SleepSample]] = [:]
}

/// 快照读写：JSON 落在 Application Support，跨启动保留；写入为后台原子写，不阻塞主线程。
private enum TrendSnapshotStore {
    private static let fileName = "trend-snapshot.json"

    private static var fileURL: URL? {
        let fm = FileManager.default
        guard let dir = try? fm.url(for: .applicationSupportDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: true) else { return nil }
        return dir.appendingPathComponent(fileName)
    }

    static func load() -> TrendSnapshot {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(TrendSnapshot.self, from: data) else {
            return TrendSnapshot()
        }
        return snapshot
    }

    static func save(_ snapshot: TrendSnapshot) {
        guard let url = fileURL, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

// MARK: - 缓存装饰器

@MainActor
final class CachingHealthRepository: HealthDataRepository {
    private let base: HealthDataRepository
    private var snapshot: TrendSnapshot

    // 本会话已拉到的新鲜值（nil = 尚未拉取）。
    private var activeDaily: [DailyMetric]?
    private var basalDaily: [DailyMetric]?
    private var exerciseSeriesCache: [TimeRange: [ExerciseSample]] = [:]
    private var workoutsCache: [WorkoutSession]?
    private var weightSeriesCache: [TimeRange: [WeightSample]] = [:]
    private var bodyFatSeriesCache: [TimeRange: [BodyFatSample]] = [:]
    private var recentWeightCache: [WeightSample]?
    private var weightStatsCache: WeightStatistics?
    private var sleepSeriesCache: [TimeRange: [SleepSample]] = [:]

    // 在途去重：并发命中同一查询时复用同一个 Task。
    private var activeDailyTask: Task<[DailyMetric], Never>?
    private var basalDailyTask: Task<[DailyMetric], Never>?
    private var exerciseSeriesTask: [TimeRange: Task<[ExerciseSample], Never>] = [:]
    private var workoutsTask: Task<[WorkoutSession], Never>?
    private var weightSeriesTask: [TimeRange: Task<[WeightSample], Never>] = [:]
    private var bodyFatSeriesTask: [TimeRange: Task<[BodyFatSample], Never>] = [:]
    private var recentWeightTask: Task<[WeightSample], Never>?
    private var weightStatsTask: Task<WeightStatistics, Never>?
    private var sleepSeriesTask: [TimeRange: Task<[SleepSample], Never>] = [:]

    init(base: HealthDataRepository) {
        self.base = base
        self.snapshot = TrendSnapshotStore.load()
    }

    // MARK: 启动预热

    /// splash 期间并行拉好三个 tab 的首屏数据——正好是各页第一次进入会请求的集合。
    /// 完成后缓存皆热，用户点开任意 tab 立即命中、无转圈。
    func prewarm() async {
        async let a = activeEnergyDailyTrend()
        async let b = basalEnergyDailyTrend()
        async let e = exerciseSeries(range: .all)
        async let w = workoutSessions()
        async let ws = weightSeries(range: .month)
        async let bf = bodyFatSeries(range: .month)
        async let rw = recentWeightRecords(limit: 5)
        async let st = weightStatistics()
        async let sl = sleepSeries(range: .year)
        _ = await (a, b, e, w)
        _ = await (ws, bf, rw, st, sl)
    }

    /// 下拉刷新时丢弃本会话命中的内存值，再从底层数据源预热一轮。
    /// 落盘快照继续保留，因此 HealthKit 暂时返回空结果时仍能回退到上次有效数据。
    func refreshCachedData() async {
        activeDaily = nil
        basalDaily = nil
        exerciseSeriesCache = [:]
        workoutsCache = nil
        weightSeriesCache = [:]
        bodyFatSeriesCache = [:]
        recentWeightCache = nil
        weightStatsCache = nil
        sleepSeriesCache = [:]

        await prewarm()
    }

    /// 清空全部缓存：内存会话值 + 在途任务引用 + 落盘快照。
    /// 不触碰事件 / 目标 / 授权等用户数据；清空后下次 prewarm 会从真实数据源重新拉取。
    func clearCache() {
        activeDaily = nil
        basalDaily = nil
        exerciseSeriesCache = [:]
        workoutsCache = nil
        weightSeriesCache = [:]
        bodyFatSeriesCache = [:]
        recentWeightCache = nil
        weightStatsCache = nil
        sleepSeriesCache = [:]

        activeDailyTask = nil
        basalDailyTask = nil
        exerciseSeriesTask = [:]
        workoutsTask = nil
        weightSeriesTask = [:]
        bodyFatSeriesTask = [:]
        recentWeightTask = nil
        weightStatsTask = nil
        sleepSeriesTask = [:]

        snapshot = TrendSnapshot()
        persistSnapshot()
    }

    private func persistSnapshot() {
        let snap = snapshot
        Task.detached(priority: .utility) { TrendSnapshotStore.save(snap) }
    }

    // MARK: 透传（不缓存）

    func requestAuthorization() async throws { try await base.requestAuthorization() }
    func homeRingMetrics() async -> HomeRingMetrics { await base.homeRingMetrics() }
    func sleepDurationTrend() async -> [DailyMetric] { await base.sleepDurationTrend() }
    func activeEnergyTrend() async -> [DailyMetric] { await base.activeEnergyTrend() }
    func events() async -> [HealthEvent] { await base.events() }
    func saveEvent(_ event: HealthEvent) async { await base.saveEvent(event) }
    func deleteEvent(_ event: HealthEvent) async { await base.deleteEvent(event) }

    // MARK: 运动页

    func activeEnergyDailyTrend() async -> [DailyMetric] {
        if let activeDaily { return activeDaily }
        if let activeDailyTask { return await activeDailyTask.value }
        let task = Task { await base.activeEnergyDailyTrend() }
        activeDailyTask = task
        let fetched = await task.value
        activeDailyTask = nil
        // 空结果（如真机授权前）只回退快照、不写缓存，待数据就绪后重试。
        guard !fetched.isEmpty else { return snapshot.activeEnergyDaily }
        activeDaily = fetched
        snapshot.activeEnergyDaily = fetched
        persistSnapshot()
        return fetched
    }

    func basalEnergyDailyTrend() async -> [DailyMetric] {
        if let basalDaily { return basalDaily }
        if let basalDailyTask { return await basalDailyTask.value }
        let task = Task { await base.basalEnergyDailyTrend() }
        basalDailyTask = task
        let fetched = await task.value
        basalDailyTask = nil
        guard !fetched.isEmpty else { return snapshot.basalEnergyDaily }
        basalDaily = fetched
        snapshot.basalEnergyDaily = fetched
        persistSnapshot()
        return fetched
    }

    func exerciseSeries(range: TimeRange) async -> [ExerciseSample] {
        if let cached = exerciseSeriesCache[range] { return cached }
        if let task = exerciseSeriesTask[range] { return await task.value }
        let task = Task { await base.exerciseSeries(range: range) }
        exerciseSeriesTask[range] = task
        let fetched = await task.value
        exerciseSeriesTask[range] = nil
        guard !fetched.isEmpty else { return snapshot.exerciseSeries[range.rawValue] ?? [] }
        exerciseSeriesCache[range] = fetched
        snapshot.exerciseSeries[range.rawValue] = fetched
        persistSnapshot()
        return fetched
    }

    func workoutSessions() async -> [WorkoutSession] {
        if let workoutsCache { return workoutsCache }
        if let workoutsTask { return await workoutsTask.value }
        let task = Task { await base.workoutSessions() }
        workoutsTask = task
        let fetched = await task.value
        workoutsTask = nil
        guard !fetched.isEmpty else { return snapshot.workouts }
        workoutsCache = fetched
        snapshot.workouts = fetched
        persistSnapshot()
        return fetched
    }

    // MARK: 体重页

    func weightSeries(range: TimeRange) async -> [WeightSample] {
        if let cached = weightSeriesCache[range] { return cached }
        if let task = weightSeriesTask[range] { return await task.value }
        let task = Task { await base.weightSeries(range: range) }
        weightSeriesTask[range] = task
        let fetched = await task.value
        weightSeriesTask[range] = nil
        guard !fetched.isEmpty else { return snapshot.weightSeries[range.rawValue] ?? [] }
        weightSeriesCache[range] = fetched
        snapshot.weightSeries[range.rawValue] = fetched
        persistSnapshot()
        return fetched
    }

    func bodyFatSeries(range: TimeRange) async -> [BodyFatSample] {
        if let cached = bodyFatSeriesCache[range] { return cached }
        if let task = bodyFatSeriesTask[range] { return await task.value }
        let task = Task { await base.bodyFatSeries(range: range) }
        bodyFatSeriesTask[range] = task
        let fetched = await task.value
        bodyFatSeriesTask[range] = nil
        guard !fetched.isEmpty else { return snapshot.bodyFatSeries[range.rawValue] ?? [] }
        bodyFatSeriesCache[range] = fetched
        snapshot.bodyFatSeries[range.rawValue] = fetched
        persistSnapshot()
        return fetched
    }

    /// 仅 limit 5 在使用；按单一缓存处理，快照同步保存。
    func recentWeightRecords(limit: Int) async -> [WeightSample] {
        if let recentWeightCache { return recentWeightCache }
        if let recentWeightTask { return await recentWeightTask.value }
        let task = Task { await base.recentWeightRecords(limit: limit) }
        recentWeightTask = task
        let fetched = await task.value
        recentWeightTask = nil
        guard !fetched.isEmpty else { return snapshot.recentWeight }
        recentWeightCache = fetched
        snapshot.recentWeight = fetched
        persistSnapshot()
        return fetched
    }

    func weightStatistics() async -> WeightStatistics {
        if let weightStatsCache { return weightStatsCache }
        if let weightStatsTask { return await weightStatsTask.value }
        let task = Task { await base.weightStatistics() }
        weightStatsTask = task
        let fetched = await task.value
        weightStatsTask = nil
        // current 为 nil 视为无数据（如真机授权前），回退快照、不写缓存。
        guard fetched.current != nil else { return snapshot.weightStatistics }
        weightStatsCache = fetched
        snapshot.weightStatistics = fetched
        persistSnapshot()
        return fetched
    }

    // MARK: 睡眠页

    func sleepSeries(range: TimeRange) async -> [SleepSample] {
        if let cached = sleepSeriesCache[range] { return cached }
        if let task = sleepSeriesTask[range] { return await task.value }
        let task = Task { await base.sleepSeries(range: range) }
        sleepSeriesTask[range] = task
        let fetched = await task.value
        sleepSeriesTask[range] = nil
        guard !fetched.isEmpty else { return snapshot.sleepSeries[range.rawValue] ?? [] }
        sleepSeriesCache[range] = fetched
        snapshot.sleepSeries[range.rawValue] = fetched
        persistSnapshot()
        return fetched
    }
}
