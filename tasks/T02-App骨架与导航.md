# T02 · App 骨架与导航

> 依赖：T01 ｜ PRD 引用：§3 信息架构、§4.3 安全区/Tab、§5 各屏概览、§9.3 全局状态

## 目标
搭好底部 5 Tab 导航外壳与全局基础设施（Toast、目标体重状态、＋记事件入口）。每个 Tab 先放占位页，App 可在 5 个页面间切换。

## 范围
**做：**
- `MainTabView`：5 Tab（总览/体重/睡眠/运动/我的），图标 + 选中态用 `brandBlue`。
- 5 个占位页（`HomeView` / `WeightView` / `SleepView` / `ExerciseView` / `ProfileView`），各显示标题即可，留给 T03–T07 填充。
- 全局 **Toast 服务**（§9.3）：可从任意页面触发，约 2.2s 自动消失。
- 全局 **目标体重状态** `goalWeight`（默认 73.0，可被 T07 修改）。
- 全局 **＋记事件入口**：在需要的页面右上角放按钮，点击调用一个 `presentEventEditor()` —— **本任务先弹出空白 sheet 占位**（"事件记录开发中"），真正实现留给 T08。

**不做：**
- 任何页面的真实内容（占位即可）。
- 事件记录弹窗的真实表单（T08）。

## 详细要求

### 1. TabView
- `MainTabView` 用 `TabView`，5 项，SF Symbols 占位图标（如 `square.grid.2x2` 总览、`scalemass` 体重、`moon` 睡眠、`figure.run` 运动、`person` 我的），label 中文。
- 选中色 `brandBlue`；遵守底部安全区。

### 2. 全局状态容器
- `AppState: ObservableObject`：持有 `goalWeight: Double = 73.0`、`events: [HealthEvent]`（从仓库初始化）、Toast 状态。
- 用 `environmentObject` 注入。
- 事件的单一数据源放这里，便于各图表叠加与 T08 写入。

### 3. Toast
- `ToastModifier` / 顶部浮层：`showToast(_ message:)`，文案如「已记录：…」。自动 2.2s 隐藏（`clearTimeout` 等价：`Task` + 取消）。

### 4. ＋记事件入口
- 在总览、体重、睡眠、运动、我的（按 PRD 各屏）右上角放 `＋ 记事件` / `＋`。
- 统一走 `appState.presentEventEditor()`，本任务弹一个占位 sheet。

## 交付文件
- `HealthApp/App/MainTabView.swift`
- `HealthApp/App/AppState.swift`
- `HealthApp/DesignSystem/Toast.swift`
- `HealthApp/Features/{Home,Weight,Sleep,Exercise,Profile}/*View.swift`（占位）
- 修改 `HealthApp/App/HealthApp.swift`：根视图改为 `MainTabView`，注入 `AppState`。

## 验收标准
- [ ] 启动进入总览，底部 5 Tab 可切换，选中态正确。
- [ ] 任意页面右上＋可弹出占位 sheet。
- [ ] `appState.showToast("测试")` 能显示并自动消失。
- [ ] `goalWeight` 默认 73.0，`events` 从仓库加载到 `AppState`。
- [ ] 占位页不含业务逻辑，编译运行无警告级错误。
