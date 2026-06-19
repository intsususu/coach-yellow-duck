# T09 · HealthKit 接入（阶段二，A3）

> 依赖：T08 ｜ PRD 引用：§2.1 分阶段、§5.6 A3、§7 HealthKit、§9.1 仓库

## 目标
新增真实数据源：`HealthKitRepository` 实现 `HealthDataRepository`，A3 导入/授权流程；授权成功后用真实 Apple 健康数据替换 mock，**UI 层不改**。

## 范围
**做：** A3 导入页、HealthKit 授权与查询、聚合、数据源切换、隐私配置。
**不做：** 改动任何已完成页面的 UI（仅替换数据来源）。

## 详细要求

### A3 · 导入 Apple 健康
- 卡片式 3 步：① 授权读取权限（体重·睡眠·运动·心率）② 同步历史数据（约 2019 至今）③ 生成分析报告（趋势·关联·建议）。
- 主按钮「连接 Apple 健康」→ 触发授权；次按钮「稍后手动导入」。
- 文案「授权后我们将读取体重、睡眠与运动记录，全部分析在本机完成。」
- 首次启动或未授权时进入此页；可从「我的」数据来源再次进入。

### HealthKitRepository（§7）
- 读取类型：`bodyMass`、`sleepAnalysis`（deep/core/REM/awake）、`activeEnergyBurned`、`appleExerciseTime`/`HKWorkout`、`heartRate`。
- 授权：`requestAuthorization(toShare: [], read:)`，仅读。
- 查询 + 聚合（§7.3）：体重周/月/年（`HKStatisticsCollectionQuery`），睡眠按夜归集分段+效率，运动按月聚合 kcal/平均心率。映射到 T01 的 `WeightSample/SleepSample/ExerciseSample`。

### 数据源切换
- 在环境注入处按"是否已授权"选择 `HealthKitRepository` 或 `MockHealthRepository`。
- 事件仍来自本机 `EventStore`（T08），与 HealthKit 无关。

### 隐私 / 配置
- `Info.plist`：`NSHealthShareUsageDescription`。
- 开启 HealthKit capability。
- 明确无网络上传。

## 交付文件
- `HealthApp/Features/Import/ImportView.swift`（A3）
- `HealthApp/Repository/HealthKitRepository.swift`
- 修改环境注入逻辑、`Info.plist`、entitlements。

## 验收标准
- [ ] 真机授权后，体重/睡眠/运动页显示真实 HealthKit 数据，UI 不变。
- [ ] 未授权 → 进入 A3 引导；可重新授权。
- [ ] 事件模块（T08）不受影响，仍本机持久化。
- [ ] 仅读不写；`Info.plist` 用途说明 + capability 配置正确。
- [ ] 未改动 T03–T08 的 UI 文件（只换数据源）。
