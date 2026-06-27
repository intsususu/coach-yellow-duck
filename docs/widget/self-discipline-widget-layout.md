# 自律打卡小组件 · 布局样式说明

> 配套文件：交互原型 [`self-discipline-widget-design.html`](self-discipline-widget-design.html)、源码 [`SelfDisciplineWidget.swift`](../../SelfDisciplineWidget/SelfDisciplineWidget.swift)。
> 本文档梳理小组件的尺寸、图片资源、各状态布局与样式 token，方便**替换插图**与**新增页面 / 状态模式**。

---

## 1. 总览

| 维度 | 取值 |
| --- | --- |
| 支持尺寸 | `systemSmall` 158×158、`systemMedium` 338×158 |
| 状态（模式） | 运动 `exercise`、别吃夜宵 `noSnack`、阅读早睡 `readSleep`、非时段 `neutral` |
| 交互 | iOS 17 App Intent：胶囊「打卡」按钮、空白处 `NoOpIntent`（点击不打开 App） |
| 背景风格 | 白底浅色插图卡：右侧放插图，左侧白色横向渐变压住，保证左栏深色文字清晰 |
| 当前激活态由 | `SelfDisciplineSchedule.activeTask(at:)` 按时段判定；落在三时段外即 `neutral` |

每张卡分三层（`ZStack`）：
1. **底层背景** `SelfDisciplineBackground`：`Color.cardBg`（白）+ 插图 + 左侧白色渐变遮罩。
2. **内容层** `SelfDisciplineEntryView.content`，外边距 `padding(.horizontal 13, .top 13, .bottom 9)`。
3. **铺满的透明 NoOp 按钮**（位于内容层下方，吃掉空白点击）。

---

## 2. 图片资源映射（替换图片看这里）

### 2.1 Widget 内的 Asset（实际渲染用）
图片放在 `SelfDisciplineWidget/Assets.xcassets/<name>.imageset/`，缺图时回退到渐变兜底。

| Asset 名 | 用途（状态） | 兜底渐变 | 角标符号 |
| --- | --- | --- | --- |
| `bg_exercise` | 运动 `exercise` | brandBlue → sleepIndigo | `sun.max.fill` |
| `bg_noSnack` | 别吃夜宵 `noSnack` | sleepDeep → textPrimary | `moon.fill` |
| `bg_readSleep` | 阅读早睡 `readSleep` | sleepIndigo → sleepDeep | `moon.stars.fill` |
| `bg_weekday` | 非时段 · **工作日**（周一~周五） | cardBg → brandBlue.18 | `sparkles` |
| `bg_default` | 非时段 · **周末**（周六/周日） | cardBg → brandBlue.18 | `sparkles` |

> 非时段按 `entry.todayIndex >= 5` 选周末/工作日图（5=周六、6=周日）。
> 替换时只需替换 `*.imageset` 里的 png 并保持文件名一致；建议沿用白底、主体偏右构图，避免左栏文字区被遮挡。

### 2.2 原型 HTML 用图（仅预览，不入包）
位于 `docs/widget/`：`fitness.png`(运动)、`yexiao.png`(夜宵)、`night.png`(早睡)、`china.png`(非时段工作日)、`superman.png`(非时段周末)。原型与 Asset 一一对应，改设计稿时同步更新即可。

---

## 3. 插图定位与渐变遮罩（构图参数）

插图用 `scaledToFit` 等比缩放到固定方形，再 `position` 定位；左侧用横向白色渐变把文字区压亮。

| 参数 | 小号 systemSmall | 中号 systemMedium |
| --- | --- | --- |
| 插图尺寸 `imageSize` | 129×129 | 147×147 |
| 插图位置 | 贴右、略偏上（中心 `x≈width+35-imageSize/2` 再左移 `imageSize*0.2`，`y=高/2-10`） | 嵌在文字与日历之间（`x=width-157-imageSize/2+imageSize*0.1`，`y=高/2`） |
| 渐变遮罩 stops | 白0.96@0 → 白0.78@0.26 → 透明@0.50 | 白0.95@0 → 白0.90@0.18 → 透明@0.40 |
| 渐变方向 | leading → trailing | 同 |

> HTML 原型用 `background-size` + `background-position` + `::after` 渐变模拟同一效果（见 `.widget.image-card::before/::after`、`.widget.medium.image-card::before`）。

---

## 4. 小号 systemSmall（158×158）

### 4.1 激活态（运动 / 夜宵 / 早睡）—— `smallBody`
纵向 `VStack(alignment:.leading)`，元素间用弹性 `Spacer(minLength:)` 撑开：

```
时段文字   windowText        11px bold   textSecondary
  ↕ Spacer(min 4)
标题       cardTitle         18px black  task.widgetTint   单行
[疲劳提示] fatigueMessage    9.5px bold  task.widgetTint   单行，仅 showsFatigueWarning
  ↕ Spacer(min 6)
打卡按钮   见 §7
  ↕ Spacer(min 8)
本周记录   WeekRecordRow     见 §6.1
```

### 4.2 非时段 —— `neutralSmall`
同层级骨架，标题换成静态「自律打卡」(`textMuted`)，按钮位置换成**本周累计**：

```
占位空行   " "               11px
标题       自律打卡           18px black  textMuted
本周累计   weekDone/weekExpected  24px black（完成数 successGreen，总数 textMuted）
本周记录   WeekRecordRow(tint: textMuted)   汇总三任务任一完成即点亮
```

---

## 5. 中号 systemMedium（338×158）

横向 `HStack(spacing:12)`：**左主区 `mediumMain`** + **右月历 `MonthCheckInCalendar`**。

- 左主区复用小号的标题层级（时段文字 / 标题 / [疲劳提示] / 打卡按钮），但 `WeekRecordRow` 被 `.hidden()` 占位以对齐高度。
- 非时段左主区同小号非时段（自律打卡 + 周累计）。
- 右侧固定宽 120pt 的本月日历（见 §6.2），整体纵向居中。

---

## 6. 打卡记录组件

### 6.1 本周记录 `WeekRecordRow`（小号）
- 7 列等宽 `HStack`，每列 = 星期文字(8px semibold, textSecondary) + 圆点格。
- 圆点格 15×15：已打卡 = 实心 `tint` 圆 + 白色 `checkmark`(8px heavy)；未打卡 = 描边圆（今日 `tint` 1.8pt，否则 `textMuted.5` 1.2pt）。
- 容器 `padding(.v 5,.h 4)` + `白0.45` 圆角 10 背景。

### 6.2 本月日历 `MonthCheckInCalendar`（中号右侧）
- 标题「本月打卡」10px heavy textSecondary。
- 星期表头 7 列（7.5px heavy textMuted）。
- `LazyVGrid` 7 列方块，`spacing 3`，单元格 `aspectRatio 1`，圆角 3：
  - 已打卡 = `tint`；未打卡 = `textMuted.16`；今日 = 描边 `tint` 1.5pt；月首前置空格 = `Color.clear`。
- 行数 = `ceil((monthOffset + 天数)/7)` 向上取整，最少 35 格（5 行）。
- `monthOffset` = 本月 1 号在周一起算周历中的前置空格数。

---

## 7. 打卡按钮 `checkButton`
左对齐白色胶囊：`「打卡」文字 + 11×11 状态圆点`。
- 文字/边框色 = `task.widgetTint`，背景白，`Capsule` 描边（已打卡 0.9、未打卡 0.45 透明度，1.2pt）。
- 状态圆点：已打卡 = 实心 tint + 白 `checkmark`(7px)；未打卡 = 仅描边 1.4pt。
- 内边距 `.h 10 / .v 4.5`，字号 11px heavy。

---

## 8. 颜色 / 字号 Token

### 任务主题色 `widgetTint`
| 状态 | 色值 | 说明 |
| --- | --- | --- |
| exercise | `#EA580C` exerciseOrange | |
| noSnack | `#16A34A` successGreen | Widget 专用绿，避免影响 App 内卡片色 |
| readSleep | `#4F46E5` sleepIndigo | |
| neutral | `#9AA1AB` textMuted | 周累计完成数另用 successGreen |

### 通用色（与原型 CSS `:root` 对齐）
`cardBg #FFFFFF`、`textPrimary #1A1F29`、`textSecondary #6B7280`、`textMuted #9AA1AB`、`brandBlue #2563EB`、`sleepDeep #5856D6`。

### 字号速查
30/24（数字统计）· 18 black（标题）· 11（时段文字 / 按钮）· 9.5（疲劳提示）· 8（周历星期）· 7.5（月历表头）。

---

## 9. 文案常量（来自 `CheckInTask`）

| 状态 | 时段 windowText | 标题 cardTitle | 副标题 subtitle |
| --- | --- | --- | --- |
| exercise | 11:00–13:00 | 运动时间 | 动起来，活力满满 |
| noSnack | 20:30–22:30 | 别吃夜宵 | 管住嘴，睡得更好 |
| readSleep | 23:30–00:30（跨午夜） | 阅读早睡 | 放下手机，准备入睡 |

> 当日边界 00:30：23:30–00:30 算同一天，凌晨打卡归前一天。疲劳提示文案 `SelfDisciplineSnapshot.fatigueMessage`（当前仅运动态示例展示）。

---

## 10. 扩展指引（新增页面 / 模式）

1. **换图**：替换 §2.1 对应 `*.imageset` png（文件名不变）；同步更新 §2.2 原型图与 HTML。
2. **加新任务态**：在 `CheckInTask` 增 case → 补 `bgAssetName / widgetTint / cornerSymbol / windowText / cardTitle / window`，在 Assets 加同名 imageset；布局自动复用 `smallBody / mediumMain`。
3. **加新尺寸**（如 systemLarge）：在 `supportedFamilies` 注册，`content` switch 增分支，并在 `imageSize / imagePosition / imageFade` 按尺寸补参数。
4. **调构图**：只动 §3 的 `imageSize / imagePosition / imageFade`，先在 HTML 原型里调好再回写 Swift。
5. 改完先按记忆约定走 Release 出包验证。
