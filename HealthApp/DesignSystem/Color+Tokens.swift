// Color+Tokens.swift
// PRD §4.1 颜色 token + §4.2 事件类型色板。
// 所有视图一律走这些 token，禁止散写 hex 字面量。

import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

extension Color {
    // MARK: - 主色 / 维度色（PRD §4.1）
    static let brandBlue      = Color(hex: "#2563eb")  // 全局主色：主按钮、选中态
    static let weightGreen    = Color(hex: "#16a34a")  // 体重维度色（复用达标绿值）
    static let sleepIndigo    = Color(hex: "#4f46e5")  // 睡眠
    static let exerciseOrange = Color(hex: "#ea580c")  // 运动 / 损伤
    static let successGreen   = Color(hex: "#16a34a")  // 下降趋势、达标
    static let warningAmber   = Color(hex: "#ca8a04")  // 「需要关注」用：偏暗的黄，提示但不刺眼

    // MARK: - 体脂趋势（先试粉色）
    static let bodyFatPink     = Color(hex: "#db2777")  // 体脂肪（kg）主轴线：玫红
    static let bodyFatPinkSoft = Color(hex: "#f472b6")  // 体脂率（%）副轴线：浅粉

    // MARK: - Apple 健康睡眠阶段
    static let sleepDeep      = Color(hex: "#5856d6")  // 深度睡眠：紫色
    static let sleepCore      = Color(hex: "#007aff")  // 核心睡眠：蓝色
    static let sleepREM       = Color(hex: "#5ac8fa")  // 快速眼动睡眠：浅蓝色
    static let sleepAwake     = Color(hex: "#ff6b55")  // 清醒时间：橙红色

    // MARK: - 背景
    static let appBg          = Color(hex: "#f5f6f8")
    static let cardBg         = Color(hex: "#ffffff")
    static let weightCardBg   = Color(hex: "#ecf6ef")  // 体重 hero 卡背景
    static let sleepCardBg     = Color(hex: "#eef0fd")  // 睡眠 hero 卡背景
    static let exerciseCardBg  = Color(hex: "#fdf2ec")  // 运动 hero 卡背景

    // MARK: - 文字
    static let textPrimary    = Color(hex: "#1a1f29")
    static let textSecondary  = Color(hex: "#6b7280")
    static let textMuted       = Color(hex: "#9aa1ab")

    // MARK: - 分隔
    static let hairline       = Color(hex: "#ededf0")

    // MARK: - 事件类型色板（PRD §4.2）
    static let eventIllness   = Color(hex: "#dc2626")  // 伤病：红（red-600，加深以与运动橙拉开）
    static let eventDrink     = Color(hex: "#7c3aed")  // 饮酒：紫
    static let eventTravel    = Color(hex: "#a16207")  // 出行：棕
    static let eventOther     = Color(hex: "#64748b")  // 其他：灰

    static let eventIllnessBg = Color(hex: "#fdecec")
    static let eventDrinkBg   = Color(hex: "#f3eefc")
    static let eventTravelBg  = Color(hex: "#f8f0e3")
    static let eventOtherBg   = Color(hex: "#f1f3f5")

    // MARK: - 运动类型色板（运动统计「类型占比」用）
    static let workoutRunning  = Color(hex: "#ea580c")  // 跑步：橙（运动主色）
    static let workoutStrength = Color(hex: "#2563eb")  // 力量：蓝
    static let workoutCycling  = Color(hex: "#16a34a")  // 骑行：绿
    static let workoutSwimming = Color(hex: "#0891b2")  // 游泳：青
    static let workoutWalking  = Color(hex: "#f59e0b")  // 步行：琥珀
    static let workoutYoga     = Color(hex: "#7c3aed")  // 瑜伽：紫
}
