// HealthDataRepository.swift
// 数据源协议（PRD §9.1）。视图层只依赖本协议，便于 Mock ↔ HealthKit 切换。

import Foundation

protocol HealthDataRepository: AnyObject {
    /// 启动预热：splash 期间提前拉好各趋势页首屏数据。默认空操作，仅缓存装饰器实现。
    func prewarm() async
    /// 用户主动刷新：重新从底层数据源拉取趋势缓存，并保留旧快照作为失败回退。
    /// 默认空操作；无缓存的数据源会在页面随后的正常查询中直接返回最新数据。
    func refreshCachedData() async
    /// 清空缓存（内存缓存 + 落盘快照），不动用户数据（事件 / 目标 / 授权）。
    /// 仅在换版本时调用，强制下次从真实数据源重新拉取。默认空操作，仅缓存装饰器实现。
    func clearCache()
    /// 请求数据源所需授权。Mock 为空操作，HealthKit 只申请读取权限。
    func requestAuthorization() async throws
    /// 首页指标卡当日数：当日睡眠时长 + 健身环锻炼分钟/活动热量及其目标。
    func homeRingMetrics() async -> HomeRingMetrics
    /// 首页睡眠卡：最近 30 日每日睡眠时长（小时）趋势。
    func sleepDurationTrend() async -> [DailyMetric]
    /// 首页运动卡：最近 30 日每日活动热量（千卡）趋势。
    func activeEnergyTrend() async -> [DailyMetric]
    /// 运动页趋势卡：最近 6 个月每日「活动消耗热量」（千卡）。
    /// 与 `activeEnergyTrend`（首页近 30 天）同口径，仅时间跨度更长，供周 / 月 / 6 个月滑动取景。
    func activeEnergyDailyTrend() async -> [DailyMetric]
    /// 运动页日均卡：最近 6 个月每日「静息（基础代谢）消耗热量」（千卡）。
    /// 与活动消耗相加即为 Health 中「含静息代谢的总消耗」。
    func basalEnergyDailyTrend() async -> [DailyMetric]
    func weightSeries(range: TimeRange) async -> [WeightSample]
    /// 最近 N 条体重测量原始记录（按日期降序）。
    func recentWeightRecords(limit: Int) async -> [WeightSample]
    /// 体重统计：当前 / 今年极值 / 历史极值 / 累计减少。
    func weightStatistics() async -> WeightStatistics
    func sleepSeries(range: TimeRange) async -> [SleepSample]
    func exerciseSeries(range: TimeRange) async -> [ExerciseSample]
    /// 运动统计卡 + 月度消耗「运动」口径：最近 24 个月的按次运动记录（含开始时间、类型、时长、消耗）。
    /// 仅含主动开始的锻炼，无锻炼的日不出现；统计卡按所选周期窗口过滤，月度图按月聚合回溯。
    func workoutSessions() async -> [WorkoutSession]
    func events() async -> [HealthEvent]
    func saveEvent(_ event: HealthEvent) async
    func deleteEvent(_ event: HealthEvent) async
}

extension HealthDataRepository {
    /// 默认无预热：Mock / HealthKit 直连数据源不需要，由 CachingHealthRepository 重写。
    func prewarm() async {}
    /// 默认无缓存可刷新：Mock / HealthKit 直连数据源由页面随后的查询直接读取。
    func refreshCachedData() async {}
    /// 默认无缓存可清：直连数据源无缓存，由 CachingHealthRepository 重写。
    func clearCache() {}
}
