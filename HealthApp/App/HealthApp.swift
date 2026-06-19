// HealthApp.swift
// @main 入口。注入 Mock + HealthKit 双数据源，由 AppState 按授权流程切换。

import SwiftUI

@main
struct HealthApp: App {
    @StateObject private var appState: AppState

    init() {
        let mockRepository = MockHealthRepository()
        let healthRepository = HealthKitRepository(eventRepository: mockRepository)
        _appState = StateObject(wrappedValue: AppState(mockRepository: mockRepository,
                                                       healthRepository: healthRepository))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isImportPresented {
                    ImportView()
                } else {
                    MainTabView()
                }
            }
            .environmentObject(appState)
            .task { await appState.loadInitialData() }
        }
    }
}
