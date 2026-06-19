// AppState.swift
// 全局状态容器（PRD §9.3）：目标体重、事件单一数据源、Toast、＋记事件入口。
// 通过 environmentObject 注入；持有仓库（协议类型），便于 T09 切换 HealthKit。

import SwiftUI

enum Tab: Hashable {
    case home, weight, sleep, exercise, profile
}

@MainActor
final class AppState: ObservableObject {

    private enum StorageKey {
        static let healthAuthorizationCompleted = "healthAuthorizationCompleted"
    }

    /// 数据源（协议类型，便于 Mock ↔ HealthKit 替换）。
    @Published private(set) var repository: HealthDataRepository
    private let mockRepository: HealthDataRepository
    private let healthRepository: HealthDataRepository
    private let userDefaults: UserDefaults

    /// 首次启动或尚未完成授权流程时展示 A3。
    @Published var isImportPresented: Bool

    /// 启动页门闩：首次数据加载完成前为 false，期间全屏展示 SplashView。
    @Published private(set) var isInitialLoadComplete = false

    /// 启动页最短展示时长，避免数据加载过快导致一闪而过。
    private let minimumSplashDuration: TimeInterval = 1.4

    /// 目标体重，默认 73.0，可由「我的」编辑，驱动目标线与「距目标」。
    @Published var goalWeight: Double = 73.0

    /// 事件单一数据源：各页只读它做图表叠加，写入只在事件模块。
    @Published var events: [HealthEvent] = []

    /// 当前选中 Tab（供首页 Hero 卡跳转体重页等使用）。
    @Published var selectedTab: Tab = .home

    /// 全局 ＋记事件弹窗（E2）的呈现状态（任意 Tab 右上＋ 唤起，新建）。
    @Published var isEventEditorPresented = false

    /// Toast 文案，非空即显示。
    @Published var toastMessage: String?

    private var toastTask: Task<Void, Never>?

    init(mockRepository: HealthDataRepository,
         healthRepository: HealthDataRepository,
         userDefaults: UserDefaults = .standard) {
        self.mockRepository = mockRepository
        self.healthRepository = healthRepository
        self.userDefaults = userDefaults
        let hasCompletedAuthorization = userDefaults.bool(forKey: StorageKey.healthAuthorizationCompleted)
        repository = hasCompletedAuthorization ? healthRepository : mockRepository
        isImportPresented = !hasCompletedAuthorization
    }

    /// 启动时从仓库加载事件到全局单一数据源。
    func loadInitialData() async {
        events = await repository.events()
    }

    /// 应用启动流程：加载首页数据，达到最短展示时长后撤下启动页。
    func startUp() async {
        guard !isInitialLoadComplete else { return }
        let start = Date()
        await loadInitialData()
        let remaining = minimumSplashDuration - Date().timeIntervalSince(start)
        if remaining > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }
        isInitialLoadComplete = true
    }

    /// A3 主按钮：只申请读取权限，成功后切换到 HealthKitRepository。
    func connectHealthKit() async throws {
        try await healthRepository.requestAuthorization()
        repository = healthRepository
        userDefaults.set(true, forKey: StorageKey.healthAuthorizationCompleted)
        isImportPresented = false
        await loadInitialData()
    }

    /// A3 次按钮：当前会话继续使用 Mock；下次启动仍会再次引导授权。
    func continueWithMockData() {
        repository = mockRepository
        isImportPresented = false
    }

    func presentHealthImport() {
        isImportPresented = true
    }

    /// 顶部 Toast：显示约 2.2s 后自动隐藏（再次调用会取消上一次计时）。
    func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled else { return }
            self?.toastMessage = nil
        }
    }

    /// 唤起全局记录事件弹窗（E2，新建）。任意 Tab 右上＋ 调用。
    func presentEventEditor() {
        isEventEditorPresented = true
    }

    /// 保存事件（新增或编辑）：写入仓库 + 更新全局单一数据源 + Toast。
    /// 已存在的 id 原地更新；否则插入列表顶部，各页图表叠加随之刷新。
    func saveEvent(_ event: HealthEvent) async {
        let isNew = !events.contains { $0.id == event.id }
        await repository.saveEvent(event)
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
        } else {
            events.insert(event, at: 0)
        }
        showToast(isNew ? "已记录：\(event.title)" : "已更新：\(event.title)")
    }

    /// 删除事件：从仓库与全局数据源移除。不弹 Toast，由事件页内联「撤销删除」承接。
    func deleteEvent(_ event: HealthEvent) async {
        await repository.deleteEvent(event)
        events.removeAll { $0.id == event.id }
    }

    /// 撤销删除：把最近删除的事件写回仓库与数据源（按日期排序自动归位）。
    func restoreEvent(_ event: HealthEvent) async {
        await repository.saveEvent(event)
        if !events.contains(where: { $0.id == event.id }) {
            events.insert(event, at: 0)
        }
        showToast("已恢复：\(event.title)")
    }
}
