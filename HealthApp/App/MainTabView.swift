// MainTabView.swift
// 底部 5 Tab 外壳 + 全局 Toast + 全局事件记录弹窗（E2）。PRD §3 / §4.3。

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    /// 包装 selectedTab：点选的目标等于当前选中项即视为"重选"，递增令牌通知该页回顶部。
    private var tabSelection: Binding<Tab> {
        Binding(
            get: { appState.selectedTab },
            set: { tab in
                if tab == appState.selectedTab {
                    appState.tabReselectToken += 1
                }
                appState.selectedTab = tab
            }
        )
    }

    var body: some View {
        NavigationStack {
            TabView(selection: tabSelection) {
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
            // 自律打卡（「我的」入口与桌面小组件深链共用）进入 App 最外层导航栈，
            // 直接盖在当前页面上打开，不经过「我的」Tab。
            .navigationDestination(isPresented: $appState.opensSelfDiscipline) {
                SelfDisciplineView()
            }
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
