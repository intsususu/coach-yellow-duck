// HealthDataRepository.swift
// 数据源协议（PRD §9.1）。视图层只依赖本协议，便于 Mock ↔ HealthKit 切换。

import Foundation

protocol HealthDataRepository: AnyObject {
    /// 请求数据源所需授权。Mock 为空操作，HealthKit 只申请读取权限。
    func requestAuthorization() async throws
    func weightSeries(range: TimeRange) async -> [WeightSample]
    func sleepSeries(range: TimeRange) async -> [SleepSample]
    func exerciseSeries(range: TimeRange) async -> [ExerciseSample]
    func events() async -> [HealthEvent]
    func saveEvent(_ event: HealthEvent) async
}
