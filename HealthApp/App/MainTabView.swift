// MainTabView.swift
// 底部 5 Tab 外壳 + 全局 Toast + 全局事件记录弹窗（E2）。PRD §3 / §4.3。

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            TabView(selection: $appState.selectedTab) {
                HomeView()
                    .tabItem { Label("总览", systemImage: "square.grid.2x2") }
                    .tag(Tab.home)

                WeightView()
                    .tabItem { Label("体重", systemImage: "scalemass") }
                    .tag(Tab.weight)

                ExerciseView()
                    .tabItem { Label("运动", systemImage: "figure.run") }
                    .tag(Tab.exercise)

                SleepView()
                    .tabItem { Label("睡眠", systemImage: "moon") }
                    .tag(Tab.sleep)

                ProfileView()
                    .tabItem { Label("我的", systemImage: "person") }
                    .tag(Tab.profile)
            }
            .tint(.brandBlue)
            // 综合分析进入 App 最外层原生导航栈，交互式返回时可实时露出来源页面。
            .navigationDestination(isPresented: $appState.showsAnalysis) {
                if let report = appState.initialAnalysisReport {
                    AnalysisReportView(report: report)
                } else {
                    AnalysisRangePickerView(repository: appState.repository) {
                        appState.showsAnalysis = false
                    }
                }
            }
        }
        .toast(message: appState.toastMessage)
        .sheet(isPresented: $appState.isEventEditorPresented) {
            EventEditorView()
        }
    }
}
