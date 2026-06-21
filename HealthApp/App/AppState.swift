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
        /// 上次运行的 App 版本（"短版本号 (构建号)"），用于检测换版本。
        static let lastRunAppVersion = "lastRunAppVersion"
    }

    /// 退后台超过此时长，再次进前台时强制重走启动页（回首页 + 重新预热）。
    private let backgroundResetThreshold: TimeInterval = 30 * 60
    /// 进入后台的时刻；回前台据此判断停留时长。
    private var backgroundEnteredAt: Date?

    /// 数据源（协议类型）。DEBUG 注入纯 Mock；Release 注入真实 HealthKit。
    @Published private(set) var repository: HealthDataRepository
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

    /// 趋势图是否叠加事件：全局开关，由首页顶部控制，各趋势页共用。
    @Published var showsEvents = true

    /// 当前选中 Tab（供首页 Hero 卡跳转体重页等使用）。
    @Published var selectedTab: Tab = .home

    /// 全局 ＋记事件弹窗（E2）的呈现状态（任意 Tab 右上＋ 唤起，新建）。
    @Published var isEventEditorPresented = false

    /// Toast 文案，非空即显示。
    @Published var toastMessage: String?

    private var toastTask: Task<Void, Never>?

    init(repository: HealthDataRepository,
         userDefaults: UserDefaults = .standard) {
        self.repository = repository
        self.userDefaults = userDefaults
        #if targetEnvironment(simulator)
        // 模拟器：纯 Mock，跳过 Apple 健康授权引导，直接进入主界面。
        isImportPresented = false
        #else
        // 真机：未完成授权前展示 A3 引导，全程使用真实 HealthKit。
        let hasCompletedAuthorization = userDefaults.bool(forKey: StorageKey.healthAuthorizationCompleted)
        isImportPresented = !hasCompletedAuthorization
        #endif
    }

    /// 启动时从仓库加载事件到全局单一数据源。
    func loadInitialData() async {
        events = await repository.events()
    }

    /// 应用启动流程：加载首页数据 + 预热各趋势页，达到最短展示时长后撤下启动页。
    /// 可重入：退后台超时（restartFromSplash）会把门闩重置为 false 后再次调用本方法。
    func startUp() async {
        guard !isInitialLoadComplete else { return }
        let start = Date()
        // 换版本：先清缓存（不动用户数据），让新版从真实数据源重新拉取，避免旧结构残留。
        if appVersionDidChange() {
            repository.clearCache()
            persistCurrentAppVersion()
        }
        // 事件（首页/各页叠加所需）与三个趋势页首屏数据并行预热，splash 期间一次拉齐。
        async let events: Void = loadInitialData()
        async let warm: Void = repository.prewarm()
        _ = await (events, warm)
        let remaining = minimumSplashDuration - Date().timeIntervalSince(start)
        if remaining > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }
        isInitialLoadComplete = true
    }

    // MARK: - 生命周期：换版本 / 后台超时

    /// 当前 App 版本标识："短版本号 (构建号)"。
    private var currentAppVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    /// 与上次运行记录的版本是否不同（含首次安装：上次为 nil）。
    private func appVersionDidChange() -> Bool {
        userDefaults.string(forKey: StorageKey.lastRunAppVersion) != currentAppVersion
    }

    private func persistCurrentAppVersion() {
        userDefaults.set(currentAppVersion, forKey: StorageKey.lastRunAppVersion)
    }

    /// 场景相位变化（由 App 入口转发）：记录进后台时刻，回前台时判断是否需要重走启动页。
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            backgroundEnteredAt = Date()
        case .active:
            if let enteredAt = backgroundEnteredAt,
               Date().timeIntervalSince(enteredAt) >= backgroundResetThreshold {
                restartFromSplash()
            }
            backgroundEnteredAt = nil
        default:
            break
        }
    }

    /// 重走启动页：重置门闩并回到首页，再次执行启动预热流程。
    private func restartFromSplash() {
        guard isInitialLoadComplete else { return } // 仍在启动页则无需重启
        isInitialLoadComplete = false
        selectedTab = .home
        Task { await startUp() }
    }

    /// A3 主按钮：申请 HealthKit 读取权限，成功后记住并撤下引导。
    func connectHealthKit() async throws {
        try await repository.requestAuthorization()
        userDefaults.set(true, forKey: StorageKey.healthAuthorizationCompleted)
        isImportPresented = false
        await loadInitialData()
        // 授权后预热：启动时（授权前）的预热只能拿到空结果，此处补齐各趋势页缓存。
        await repository.prewarm()
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
        var updatedEvents = events
        if let index = updatedEvents.firstIndex(where: { $0.id == event.id }) {
            updatedEvents[index] = event
        } else {
            updatedEvents.insert(event, at: 0)
        }

        // 整体替换 @Published 数组，立即、明确地通知所有已存活 Tab 重绘图表。
        events = updatedEvents
        await repository.saveEvent(event)
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
