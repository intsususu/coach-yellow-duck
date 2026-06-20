// SleepSample.swift
// 睡眠样本（单晚）。PRD §6.1。

import Foundation

struct SleepSample: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let totalMinutes: Int          // 当晚总时长（分）
    var deepMinutes: Int? = nil    // 深睡
    var coreMinutes: Int? = nil    // 核心
    var remMinutes: Int? = nil     // REM
    var awakeMinutes: Int? = nil   // 清醒
    var efficiency: Double? = nil  // 效率 0–1
    var bedtime: Date? = nil       // 入睡时刻（当晚最早一段睡眠的开始）
    var wakeTime: Date? = nil      // 起床时刻（当晚最晚一段睡眠的结束）

    var totalHours: Double { Double(totalMinutes) / 60.0 }
}
