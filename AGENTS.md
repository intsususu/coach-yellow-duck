# AGENTS.md · 项目技术约束

> 给 Claude / Codex 等编码 agent 的硬性约束。施工前**先读本文件 + [PRD](健康数据分析App-PRD.md) + 当前任务文件 [tasks/](tasks/)**。
> 本文件是规则，不是教程；与 PRD 冲突时以 PRD 的**数据契约**（数值/颜色/文案）为准，其余以本文件为准。

## 1. 技术栈（不可替换）
- **平台**：iOS **16.0+**（Swift Charts 依赖 iOS 16，不得降低部署目标）。
- **语言/UI**：Swift + **SwiftUI**。**禁止** UIKit、Storyboard、SwiftUI 以外的 UI 方案（除非系统能力缺失且在任务中说明）。
- **图表**：**Swift Charts**（`import Charts`）。不引入第三方图表库。
- **数据源**：阶段一 Mock，阶段二 **HealthKit**。
- **本机存储**：事件用 **SwiftData**（iOS 17+ 时）或 **Core Data**；低版本回退 Core Data。不得引入外部 DB。
- **依赖管理**：优先零三方依赖；确需时用 **Swift Package Manager**，并在 PR 说明理由。**禁止** CocoaPods / Carthage。

## 2. 架构（必须遵守）
- **MVVM + Repository**。视图不直接访问数据源，一律经 `HealthDataRepository` 协议。
- 数据源通过**环境注入**（`environmentObject` / `@Environment`），保证 `MockHealthRepository` ↔ `HealthKitRepository` 可无缝切换。**视图层不感知具体实现。**
- 全局状态集中在 `AppState`（`goalWeight`、`events`、Toast）。事件是**单一数据源**，各页只读它做图表叠加，写入只在事件模块。
- 异步用 **async/await** + `@MainActor`，UI 更新在主线程。

## 3. 目录与文件边界（控制变更范围）
- 目录结构见 PRD §9.2，由 T01 建立，后续任务**只在自己 `Features/<页面>` 范围内新增文件**。
- 共享代码只放 `DesignSystem/`、`Charts/`、`Models/`、`Repository/`。修改这些公共文件需在 PR 说明影响面。
- **一个任务只改一个范围**：做 T0X 时不要顺手改别的页面/重构无关代码。跨范围改动 = 拆成新任务。
- 不删除/改名已有公共 API，除非任务明确要求。

## 4. 数据契约（禁止篡改）
- 颜色 token（PRD §4.1）、事件类型色板（§4.2）、Mock 数据集（§6.2）、各卡片默认数值（§5）**原样使用**，不得调整数值或配色。
- 派生指标（当前/累计/距目标、均值等）必须**由数据计算得出**，不得硬编码结果字符串（结果应与 mock 一致，如 77.1 / -13.9 / 4.1）。
- 颜色一律走 `Color+Tokens`，**禁止**在视图里散写 hex 字面量。
- 文案使用中文，与原型一致。

## 5. 隐私与安全（红线）
- 所有数据**仅本机处理，禁止任何网络上传 / 第三方 SDK / 分析埋点 / 远程日志**。
- HealthKit **仅读不写**（`requestAuthorization(toShare: [], read:)`）。
- `Info.plist` 必须含 `NSHealthShareUsageDescription`；启用 HealthKit capability。
- 不在代码/日志中泄露健康数据；不写入 UserDefaults 明文敏感信息（事件用本机数据库）。

## 6. 代码规范
- Swift API 设计指南命名；类型 `UpperCamelCase`，成员 `lowerCamelCase`。
- 视图小而专一，可复用 UI 抽到 `DesignSystem/Components`。
- 优先 `struct` 与值语义；`ObservableObject` 仅用于状态容器。
- 避免强制解包 `!`（除明确不变量）；处理空数据与加载/错误态（PRD §4.4）。
- 注释与命名密度对齐周边代码；不写无意义注释。

## 7. 提交与验收
- 每个任务对应一次可独立 review 的提交；commit message 注明任务号（如 `T03: 首页总览`）。
- 完成任务必须自检该任务文件的**验收标准**清单全过。
- 工程需能在 iOS 16 模拟器编译运行无报错；阶段一（T01–T08）不依赖真机 / HealthKit。
- 未经用户要求，不执行 `git push`、不发布、不改 CI/签名配置。

### 7.1 版本号管理
- 版本规则以 [`docs/VERSIONING.md`](docs/VERSIONING.md) 为准：`MARKETING_VERSION` 使用 `MAJOR.MINOR.PATCH`，`CURRENT_PROJECT_VERSION` 为单调递增构建号。
- 新克隆后确认已执行 `git config core.hooksPath .githooks`；正常提交必须保留 pre-commit hook，由它自动递增 PATCH 与构建号并暂存 `project.pbxproj`。
- 创建 PR 前若包含独立功能，必须先询问用户是否升级 MINOR；用户确认后运行 `./scripts/bump-minor.sh`，不得手动改版本号或绕过脚本。
- MAJOR 仅在用户明确决定大版本升级时运行 `./scripts/bump-major.sh`。
- 合并版本号冲突时，`MARKETING_VERSION` 的 PATCH 与 `CURRENT_PROJECT_VERSION` 均保留较大值。

## 8. 范围纪律
- 不擅自增加 PRD §2.3 / §11 列为「不做 / Backlog」的功能（提醒推送、导出落地、Watch、云同步、多账号等）。
- 发现 PRD 未决问题（§12.2）或需求歧义时**先问，不臆测**。
- 不引入与当前任务无关的重构、依赖、抽象。
