# 加油吖！

一款以体重管理为核心的 iOS 个人健康数据分析 App。它将 Apple 健康中的体重、睡眠和运动数据整理成趋势图，并把生病、损伤、饮酒、旅行等特殊事件叠加到时间轴上，帮助用户理解数据波动背后的原因。

应用坚持隐私优先：HealthKit 仅读取，健康数据和分析过程均留在本机，不接入账号、云同步、第三方统计或远程日志。

## 当前能力

- **总览**：展示最新体重、睡眠时长、活动热量、近 30 日趋势和近期事件；支持下拉刷新。周日会根据本周数据生成「本周小结」。
- **体重分析**：支持周、月、年、全部四种范围，展示可横向回溯的趋势、目标差距、历史统计和最近记录。
- **运动分析**：支持周、月、6 个月范围，查看活动消耗趋势、基础代谢、运动次数、时长、心率及月度消耗。
- **睡眠分析**：支持周、月、6 个月范围，可在睡眠质量分与睡眠阶段趋势之间切换，并分析低质量睡眠。
- **事件记录**：记录生病、损伤、饮酒、旅行和其他事件，支持单日或时间段、编辑、删除及撤销删除。
- **事件叠加**：事件可统一显示在体重、运动和睡眠趋势图中；点击标记或图例可查看对应事件详情。
- **综合分析**：按近一周、近一个月、近三个月或自定义日期生成体重、运动、睡眠联合报告，并可渲染成长图分享。
- **个人设置**：编辑头像、昵称、身高、年龄、性别和状态标签，调整目标体重，管理数据来源与事件。
- **启动与缓存**：启动时并行预热趋势数据，使用本地快照加速冷启动；版本变化时自动清理趋势缓存。

底部导航当前顺序为：**总览 / 体重 / 运动 / 睡眠 / 我的**。

## 数据源

工程通过 `HealthDataRepository` 协议隔离数据来源，视图层不感知具体实现。

| 运行环境 | 数据来源 | 说明 |
|---|---|---|
| iOS 模拟器（Debug） | `MockHealthRepository` | 使用内置数据，不请求 HealthKit，适合界面开发和演示 |
| iPhone 真机 | `HealthKitRepository` | 请求 Apple 健康只读权限，读取真实体重、睡眠、活动热量、锻炼和心率数据 |

两种数据源外层均由 `CachingHealthRepository` 包装，负责启动预热、本地趋势快照和并发查询去重。真机首次启动会先进入 Apple 健康授权引导。

## 技术栈

- Swift、SwiftUI
- Swift Charts
- HealthKit（只读）
- MVVM + Repository
- async/await、`@MainActor`
- SF Symbols、PhotosUI
- 零第三方依赖

当前 Xcode 工程的部署目标为 **iOS 17.0+**，Scheme 和 Target 均为 `HealthApp`。

## 运行项目

### 环境要求

- macOS 与 Xcode
- iOS 17.0+ 模拟器，或支持 HealthKit 的 iPhone
- 真机运行时需要在 Xcode 中配置自己的开发团队和签名

### 打开并运行

```bash
git clone git@github.com:intsususu/coach-yellow-duck.git
cd coach-yellow-duck
git config core.hooksPath .githooks
open HealthApp.xcodeproj
```

在 Xcode 中选择 `HealthApp` Scheme：

1. 使用模拟器运行，可直接查看 Mock 数据和全部主要界面。
2. 使用真机运行，按引导授予 Apple 健康读取权限。

也可以在命令行验证模拟器构建：

```bash
xcodebuild \
  -project HealthApp.xcodeproj \
  -scheme HealthApp \
  -destination 'generic/platform=iOS Simulator' \
  build
```

## HealthKit 权限

真机数据源仅读取以下类型：

- 体重
- 睡眠分析（深度、核心、快速眼动、清醒）
- 活动能量与静息能量
- 锻炼记录与锻炼时长
- 心率

工程已配置 HealthKit capability 和 `NSHealthShareUsageDescription`。授权调用不包含任何写入类型：

```swift
requestAuthorization(toShare: [], read: readTypes)
```

如果需要改变读取范围，必须同步检查隐私文案、Capability 和 `HealthKitRepository`，并继续保持只读。

## 架构

```text
SwiftUI View
    ↓
ViewModel / AppState
    ↓
HealthDataRepository
    ↓
CachingHealthRepository
    ├── MockHealthRepository       模拟器数据
    └── HealthKitRepository        真机健康数据
            └── EventRepository    本机事件
```

- `AppState` 管理全局目标体重、事件、Tab、Toast、授权引导和综合分析导航。
- 事件是全局单一数据源；各趋势页只读取事件进行图表叠加，写入集中在事件模块。
- 所有健康数据查询均经 Repository；视图不直接访问 HealthKit。
- 趋势快照保存在 Application Support，用于冷启动快速回显。
- 用户资料、头像和事件只保存在本机。

## 目录结构

```text
HealthApp/
├── App/                 App 入口、全局状态、Tab 与启动页
├── Models/              体重、睡眠、运动、事件及统计模型
├── Repository/          Repository 协议、Mock、HealthKit、缓存与事件存储
├── Features/
│   ├── Home/            总览
│   ├── Weight/          体重分析
│   ├── Exercise/        运动分析
│   ├── Sleep/           睡眠分析
│   ├── Events/          事件编辑与时间轴
│   ├── Analysis/        综合分析与分享报告
│   ├── Profile/         个人资料与设置
│   └── Import/          Apple 健康授权引导
├── Charts/              Swift Charts 图表
├── DesignSystem/        颜色 Token 与通用组件
└── Assets.xcassets/     App 图标、头像与启动页资源
```

## 开发约定

开始修改前请先阅读：

1. [`AGENTS.md`](AGENTS.md)：技术约束、隐私红线与范围纪律。
2. [`产品需求文档`](docs/最早原型图/健康数据分析App-PRD.md)：数值、颜色、文案和 Mock 数据契约。
3. [`施工任务清单`](tasks/README.md) 及对应任务文件。

关键规则：

- UI 使用 SwiftUI，图表使用 Swift Charts。
- 遵循 MVVM + Repository，不允许视图直接访问数据源。
- 颜色统一使用 `Color+Tokens`，禁止在视图中散写十六进制颜色。
- HealthKit 仅读不写；禁止上传健康数据或接入第三方分析 SDK。
- 一次任务只修改一个范围，不顺手重构无关模块。
- 未经明确要求，不推送分支、不发布、不修改 CI 或签名配置。

## 版本管理

版本规则详见 [`docs/VERSIONING.md`](docs/VERSIONING.md)。

- 每次普通提交由 `.githooks/pre-commit` 自动增加 PATCH 和构建号，并暂存 `project.pbxproj`。
- 独立功能准备创建 PR 时，先确认是否升级 MINOR，再运行 `./scripts/bump-minor.sh`。
- MAJOR 版本仅在明确决定大版本升级时运行 `./scripts/bump-major.sh`。
- 新克隆后务必执行：

```bash
git config core.hooksPath .githooks
```

## 设计与文档

- [`产品需求文档`](docs/最早原型图/健康数据分析App-PRD.md)
- [`高保真离线原型`](docs/最早原型图/健康App-高保真原型-离线版.html)
- [`线框图`](docs/最早原型图/健康数据分析App-线框图.html)
- [`综合分析报告设计`](docs/综合分析报告/综合分析报告设计.md)
- [`综合分析报告原型`](docs/综合分析报告/prototype.html)
- [`睡眠质量评分设计`](docs/睡眠质量评分设计.md)
- [`设计验收记录`](docs/design-qa.md)
- [`任务拆分`](tasks/README.md)

## 隐私说明

- 健康数据只在设备本机读取、缓存和分析。
- 应用不会向 Apple 健康写入任何数据。
- 应用不包含账号体系、云同步、第三方埋点或远程日志。
- iCloud 同步、导出、提醒、Widget 和 Apple Watch 均不在当前版本范围内。
