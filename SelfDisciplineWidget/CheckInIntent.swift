// CheckInIntent.swift
// 桌面交互式打卡（iOS 17+ App Intents）：在小组件上直接点「打卡」，写入共享存储并刷新组件，无需打开 App。

import AppIntents
import WidgetKit

struct CheckInIntent: AppIntent {
    static var title: LocalizedStringResource = "自律打卡"
    static var description = IntentDescription("切换当前时段任务的打卡状态")

    /// 任务标识（CheckInTask.rawValue）。用字符串以便 AppIntents 序列化。
    @Parameter(title: "任务")
    var taskRawValue: String

    init() {}

    init(task: CheckInTask) {
        self.taskRawValue = task.rawValue
    }

    func perform() async throws -> some IntentResult {
        if let task = CheckInTask(rawValue: taskRawValue) {
            CheckInStore().toggle(task)
            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result()
    }
}
