// HealthApp.swift
// @main 入口。按「运行环境」注入数据源（不再按 Debug/Release 构建类型）：
//   · 模拟器 —— 纯 MockHealthRepository，离线 mock 数据，不连接真实 HealthKit；
//   · 真机（无论 Debug/Release）—— HealthKitRepository（真实数据）+ EventRepository（本机事件，无 mock）。
// 改用 targetEnvironment(simulator) 是因为 Xcode「运行」默认走 Debug 配置，若按 DEBUG 判定，
// 真机调试运行会错误地显示模拟数据。

import SwiftUI

/// 全局运行配置（编译期决定，运行时不可改）。
enum AppConfig {
    /// 是否使用纯 Mock 数据源。
    /// 模拟器为 true：供 Claude/Codex 离线调试，无需真实 HealthKit；
    /// 真机为 false：仅真实 HealthKit，mock 代码不编入真机二进制。
    #if targetEnvironment(simulator)
    static let useMockData = true
    #else
    static let useMockData = false
    #endif
}

@main
struct HealthApp: App {
    @StateObject private var appState: AppState

    init() {
        let repository: HealthDataRepository
        #if targetEnvironment(simulator)
        // 模拟器：纯 Mock 数据源，不触碰真实 HealthKit。
        repository = MockHealthRepository()
        #else
        // 真机：真实 HealthKit；事件走本机持久化（无 mock 种子）。
        repository = HealthKitRepository(eventRepository: EventRepository())
        #endif
        _appState = StateObject(wrappedValue: AppState(repository: repository))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if appState.isImportPresented {
                        ImportView()
                    } else {
                        MainTabView()
                    }
                }
                .environmentObject(appState)

                // 首页加载完成前，全屏叠加启动页；完成后淡出。
                if !appState.isInitialLoadComplete {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .animation(.easeOut(duration: 0.35), value: appState.isInitialLoadComplete)
            .task { await appState.startUp() }
        }
    }
}
