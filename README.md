# Handoff: 健康数据分析 iOS App

## Overview

A personal health analytics app for iOS. The core use case is **weight-loss tracking with context**: the user logs weight, sleep, and exercise data (synced from Apple Health), records special events (illness, injury, drinking, travel), and sees how those events correlate with data fluctuations on charts.

The design was built as a high-fidelity interactive HTML prototype. The files in this bundle are **design references** — not production code to copy directly. Your task is to **recreate these designs in SwiftUI** using Swift best practices, native components where appropriate, and the design tokens documented below.

## Fidelity

**High-fidelity.** The prototype shows final colors, typography, spacing, chart styles, and interactions. Recreate pixel-accurately. Where SwiftUI offers native equivalents (e.g. `TabView`, `sheet`, system fonts), prefer them — but match the visual output to the prototype.

---

## Design Tokens

### Colors

```swift
// Primary
let colorPrimary       = Color(hex: "#2F6BFF")   // Blue — weight accent, CTAs
let colorPrimaryDark   = Color(hex: "#1F4FD6")   // Gradient end for weight hero card

// Backgrounds
let colorAppBG         = Color(hex: "#F5F6F8")   // Main screen background
let colorCardBG        = Color(hex: "#FFFFFF")   // Card surface
let colorSubtleBG      = Color(hex: "#ECF0F3")   // Segmented control track

// Text
let colorTextPrimary   = Color(hex: "#1F2733")   // Headings, large numbers
let colorTextSecondary = Color(hex: "#9AA6B4")   // Captions, labels
let colorTextBody      = Color(hex: "#5B6675")   // Body copy

// Data accents
let colorWeight        = Color(hex: "#2F6BFF")   // Weight line + cards
let colorSleep         = Color(hex: "#6366F1")   // Sleep bars + hero
let colorSleepDark     = Color(hex: "#4338CA")   // Deep sleep segment
let colorSleepLight    = Color(hex: "#A5B4FC")   // REM segment
let colorExercise      = Color(hex: "#16A34A")   // Exercise bars + hero
let colorGoalLine      = Color(hex: "#EA580C")   // Weight goal dashed line

// Event types
let colorEventIllness  = Color(hex: "#EF4444")   // 生病 — red
let colorEventInjury   = Color(hex: "#EA580C")   // 损伤 — orange
let colorEventDrink    = Color(hex: "#7C3AED")   // 饮酒 — purple
let colorEventTravel   = Color(hex: "#0891B2")   // 旅行 — cyan
let colorEventOther    = Color(hex: "#64748B")   // 其他 — slate

// Semantic
let colorSuccess       = Color(hex: "#16A34A")
let colorWarning       = Color(hex: "#EA580C")
let colorDanger        = Color(hex: "#EF4444")
```

### Typography

All text uses the system font (San Francisco). **Do not import a custom font** — use `.system` with matching weights.

| Role | Size | Weight | Usage |
|---|---|---|---|
| Screen title | 26pt | .heavy | Tab screen headings |
| Hero number | 42–46pt | .heavy | Weight kg, Sleep hours, Kcal |
| Hero number unit | 15pt | .medium | "kg", "小时", "千卡" |
| Section header | 16pt | .heavy | Card section titles |
| Card title | 14pt | .semibold | List item titles |
| Body | 13–14pt | .regular | Descriptions, notes |
| Caption | 11–12pt | .medium | Labels, dates, secondary info |
| Micro | 10pt | .medium | Chart axis labels |

### Corner Radius

| Token | Value | Usage |
|---|---|---|
| `radiusHero` | 22pt | Hero gradient cards |
| `radiusCard` | 20pt | Stat cards, quick-stat tiles |
| `radiusRow` | 18pt | Settings rows, event cards |
| `radiusChip` | 13pt | Type selector chips |
| `radiusPill` | 999pt | Pills, tags |
| `radiusButton` | 16pt | Primary action button |

### Spacing

Base unit = 4pt. Prefer multiples.

| Token | Value |
|---|---|
| `spacingXS` | 4pt |
| `spacingS` | 8pt |
| `spacingM` | 12pt |
| `spacingL` | 16pt |
| `spacingXL` | 20pt |
| `screenPadding` | 20pt (horizontal) |
| `cardGap` | 13–14pt |

### Shadows

```swift
// Standard card shadow
.shadow(color: Color(hex: "#1F2733").opacity(0.10), radius: 10, x: 0, y: 5)

// Hero card shadow (colored glow matching accent)
// Weight: .shadow(color: colorPrimary.opacity(0.35), radius: 17, x: 0, y: 9)
// Sleep:  .shadow(color: colorSleep.opacity(0.35), radius: 17, x: 0, y: 9)
// Exercise: .shadow(color: colorExercise.opacity(0.30), radius: 17, x: 0, y: 9)
```

---

## App Structure

```
App
└── ContentView
    └── TabView (5 tabs, bottom bar)
        ├── HomeView          (总览)
        ├── WeightView        (体重)
        ├── SleepView         (睡眠)
        ├── ExerciseView      (运动)
        └── ProfileView       (我的)

Shared sheet (presented from any tab):
    └── AddEventSheet
```

### Tab Bar

5 tabs, standard iOS `TabView`. Active tab uses `colorPrimary` (#2F6BFF), inactive uses `colorTextSecondary`.

| Index | Label | SF Symbol |
|---|---|---|
| 0 | 总览 | `square.grid.2x2` |
| 1 | 体重 | `chart.line.uptrend.xyaxis` |
| 2 | 睡眠 | `moon.fill` |
| 3 | 运动 | `flame.fill` |
| 4 | 我的 | `person.fill` |

---

## Screens

### 1. HomeView (总览)

**Purpose:** Daily snapshot — current weight, sleep summary, exercise summary, recent events, insight callout.

**Layout (top → bottom, 20pt horizontal padding):**

#### Header row
- Left: date string ("6月18日 星期四", caption/secondary) + greeting ("李，下午好", 25pt heavy)
- Right: "＋ 记事件" pill button → opens `AddEventSheet`
  - Background: `#1F2733`, text white, padding 9×14pt, radius 999pt
  - Shadow: `rgba(31,39,51,.5)` 14pt blur −4pt y

#### Weight Hero Card
Full-width, gradient background `#2F6BFF → #1F4FD6` (150°), radius 22pt, shadow (blue glow).
- Top-left: label "当前体重" (13pt .medium, white 82% opacity) + big number `77.1 kg` (46pt heavy white)
- Top-right: change pill "较起点 ↓13.9" (white 16% bg, 999pt radius, 12pt semibold)
- Middle: mini sparkline SVG (last 12 weekly points, white line + white fill gradient, 42pt tall)
- Bottom row: "距目标 73kg · 还差 **4.1kg**" left, "查看趋势 ›" right (12pt, white 85% opacity)
- Progress bar: white 22% bg track, white fill, height 7pt, radius 5pt
- Tappable → navigates to WeightView tab

#### Quick Stats (2-column grid, gap 13pt)
Two equal cards (radius 20pt, white, card shadow):

**Sleep card** (tappable → SleepView):
- Accent dot + "睡眠 · 近30天" (indigo, 12pt semibold)
- "7.3" (28pt heavy, `#1F2733`) + "h/晚" (13pt secondary)
- "效率 95% · 良好" (12pt, `colorSuccess`)

**Exercise card** (tappable → ExerciseView):
- Accent dot + "运动 · 日均" (green, 12pt semibold)
- "434" (28pt heavy) + "千卡" (13pt secondary)
- "68分钟 · 心率121" (12pt secondary)

#### Recent Events Section
Header: "近期事件" (16pt heavy) + "＋ 记录" link (13pt `colorPrimary`)

List of up to 4 most recent `HealthEvent` rows (radius 16pt, white, card shadow):
- Left icon tile (38×38pt, radius 11pt, event bg color): rotated diamond (11×11pt, event color)
- Center: title (14pt semibold, `colorTextPrimary`) + date + note (11.5pt secondary)
- Right pill: type label (11pt semibold, event color on event bg, radius 999pt)

#### Insight Card
White card, radius 20pt. Header "💡 关联洞察" (13pt bold). Body text 13pt, line-height 1.65, color `#5B6675`.

---

### 2. WeightView (体重)

**Purpose:** Weight trend over time with goal line and event markers.

**Layout:**

#### Header row
"体重" title (26pt heavy) + "＋" circular button (38×38pt, `colorPrimary` bg, white, radius 50%) → `AddEventSheet`

#### Range Segmented Control
Inline: 周 / 月 / 年. See "Segmented Control" component below.

#### Chart Card
White card, radius 22pt, padding 18×16pt.
- Legend row: "体重 (kg)" left, "— 目标 73" (orange) + "◆ 事件" (red) right
- **Line chart** (see Chart spec below): shows weight series for selected range
  - Blue line (#2F6BFF), 2.6pt stroke, rounded caps
  - Area fill: blue 0→22% opacity gradient
  - Dashed orange goal line at 73kg
  - Diamond markers (10×10pt rotated 45°) at event dates, colored by event type
  - Last point: filled circle 4pt radius

#### 2×2 Stats Grid (radius 18pt cards)
- 较起点: −13.9 kg (green, 24pt heavy)
- 距目标: 4.1 kg (24pt heavy)
- 历史最低: 71.9 kg
- 历史最高: 91.2 kg

#### Event Impact Card
Pink-tinted card (`#FDECEC` bg, `#F6C9C9` border, radius 18pt). Shows most relevant recent event with its impact note.

---

### 3. SleepView (睡眠)

**Purpose:** Sleep duration and stage breakdown.

**Layout:**

#### Header row
"睡眠" title + "＋" button (indigo bg `#6366F1`)

#### Sleep Hero Card
Gradient `#5B5FF0 → #4338CA` (150°), radius 22pt, indigo shadow.
- Left: "平均睡眠 · 近30天" + "7.3 小时" (42pt heavy white)
- Right: "效率 95%" pill + "夜醒 8.3 次"
- Stage progress bar (13pt tall, radius 7pt):
  - Deep sleep 8.9% → `#312E81`
  - Core 64.3% → `#6366F1`
  - REM 21.7% → `#A5B4FC`
  - Awake 5% → `#E0E7FF`
- Stage labels below bar: 深睡 / 核心 / REM / 清醒 (10.5pt, white 85% opacity)

#### 2-column Stats
- 深睡 日均: **41分** (22pt heavy, `#312E81`) + "偏少 · 建议↑" (red caption)
- REM 日均: **100分** (indigo) + "正常区间" (green caption)

#### Bar Chart Card (每晚时长)
White card, radius 22pt. Header "每晚时长" + range picker (7天/14天).
- Vertical bars for each night (minutes), `colorSleep` fill
- Bars during travel period: `#A5B4FC` (lighter indigo)
- Event marker diamond above bar on drink night

#### Event Impact Card
Purple-tinted (`#F3EEFC`, `#E0D2F7` border). Shows drink/travel event impact.

---

### 4. ExerciseView (运动)

**Purpose:** Exercise frequency, calorie burn, and activity types.

**Layout:**

#### Header row
"运动" title + "＋" button (green bg `#16A34A`)

#### Exercise Hero Card
Gradient `#1BB15C → #15803D` (150°), radius 22pt, green shadow.
- Left: "日均消耗 · 近30天" + "434 千卡" (42pt heavy white)
- Right: "月均 27.5 次" pill + "约 15 天/月"
- Summary line: "主要在**中午**运动 · **有氧**占 66% · 累计燃脂约 5.1kg"

#### 3-column Stats Grid (radius 18pt)
- 日均时长: 68分
- 有氧心率: 121 bpm
- 累计千卡: 39.5千

#### Bar Chart Card (近6个月)
White card, radius 22pt. Header "近 6 个月" + metric picker (消耗/心率).
- Green bars (`#16A34A`) for kcal mode, teal (`#0D9488`) for HR mode
- Orange diamond marker on injury month (May)

#### Event Impact Card
Orange-tinted (`#FDF1EA`, `#F6D6BF` border). Shows injury event impact.

---

### 5. ProfileView (我的)

**Purpose:** User profile, goal settings, data source config, settings.

**Layout:**

#### Profile Header
Avatar circle (60×60pt, gradient blue, first initial 24pt heavy white) + name + stats line.

#### Goal Card
Blue-tinted card (`#EEF4FF` bg, `#CFE0FF` border, radius 20pt).
- "目标体重" label + "编辑" button → opens `AddEventSheet` (or future goal-edit sheet)
- "73.0 kg" (30pt heavy blue) + "还差 4.1kg" (green)
- Progress bar (9pt, blue fill on light blue track)

#### Settings Groups (radius 18pt, white)
Group 1: 数据来源 (Apple 健康 ✓) / 单位 / 每日提醒  
Group 2 (tappable row): ＋ 记录特殊事件  
Group 3: 导出数据 / 关于

---

## Components

### Segmented Control

Native-style inline picker. Use `Picker` with `.segmented` style or custom implementation.

```swift
// 3 options: 周/月/年 (weight), 7天/14天 (sleep), 消耗/心率 (exercise)
// Track: #ECF0F3, radius 11pt, padding 3pt
// Active chip: white bg, radius 8pt, shadow, accent-colored text, .bold
// Inactive: transparent bg, secondary text color, .medium
// Height: ~34pt total
```

### Event Diamond Marker (chart overlay)

A 10×10pt `Rectangle` rotated 45°, filled with the event's color, positioned above the corresponding bar/point on the chart.

### AddEventSheet (Bottom Sheet)

Presented modally as a `.sheet` from any screen.

**Content (top → bottom):**
1. Drag handle (40×5pt, radius 3pt, `#D3D8DF`, centered)
2. Header: "记录特殊事件" (20pt heavy) + close button (30×30pt, `#E8EBF0` bg)
3. **类型** label + type chip row (5 options: 生病/损伤/饮酒/旅行/其他)
   - Each chip: diamond icon (9×9pt rotated 45°) + label, border radius 13pt
   - Selected: event color border + event bg fill + bold text
   - Unselected: `#E2E6EC` border + white bg
4. **标题** label + `TextField` (radius 14pt, white bg, `#E2E6EC` border 1.5pt, 15pt text)
5. **日期** label + 3 date chips (今天/昨天/前天), pill-style, same selected/unselected logic as type chips
6. **备注** label + `TextEditor` 3 rows (same style as TextField)
7. Info banner (blue tinted, `#EEF4FF`, 📈 icon + hint text)
8. "保存事件" primary button (full-width, radius 16pt, `colorPrimary` bg, white 16pt bold, blue glow shadow)

**On save:** dismiss sheet + show toast notification for 2.2 seconds.

### Toast

Centered at bottom of screen (above tab bar), pill shape. `#1F2733` bg, white text, 14pt semibold. Animate in with scale+fade, auto-dismiss after 2.2s.

---

## Interactions & Behavior

| Trigger | Action |
|---|---|
| Tap weight hero card | Switch to 体重 tab |
| Tap sleep quick-stat | Switch to 睡眠 tab |
| Tap exercise quick-stat | Switch to 运动 tab |
| Tap "＋ 记事件" (any screen) | Present `AddEventSheet` |
| Tap type chip | Select type, update chip styles |
| Tap date chip | Select date |
| Tap "保存事件" | Append event to list, dismiss sheet, show toast |
| Tap range control (周/月/年) | Switch chart data series, animate transition |
| Tap metric control (消耗/心率) | Switch exercise chart metric |
| Scroll | Standard iOS momentum scroll, no bounce clipping |

### Transitions
- Tab switch: `.easeInOut(duration: 0.2)` fade
- Sheet: standard iOS `.sheet` (slide up)
- Toast: fade + translateY(8pt) in, fade out after 2.2s

---

## Charts

Charts should be implemented with **Swift Charts** (iOS 16+).

### Weight Line Chart

```swift
// Data: [WeightEntry] (date, kg)
// Range options: weekly (last 16 pts) / monthly (last 12 months) / yearly (all years)
// 
// Marks:
// 1. AreaMark — x: date, yStart: minKg, y: kg — fill blue opacity gradient
// 2. LineMark — x: date, y: kg — stroke #2F6BFF, width 2.6
// 3. RuleMark — y: goalKg — stroke #EA580C dashed
// 4. PointMark at last data point — filled circle
// 5. For each event in date range:
//    AnnotationMark or PointMark at event.date — rotated diamond, event color
//
// X axis: show 3 labels (first, mid, last), format as "M月"
// Y axis: hidden (value shown in stat cards)
// Animation: .animation(.easeInOut, value: selectedRange)
```

### Sleep Bar Chart

```swift
// Data: [SleepEntry] (date, minutes)
// Range: last 7 or 14 nights
//
// Marks:
// 1. BarMark — x: date, y: minutes — fill colorSleep
//    → travel dates: fill colorSleepLight (#A5B4FC)
// 2. For drink event date: PointMark above bar — diamond, colorEventDrink
//
// X axis: show day-of-week or M/dd
// Corner radius on bars: 4pt
```

### Exercise Bar Chart

```swift
// Data: [ExerciseMonth] (label, kcal, avgHR)
// Metric: kcal or avgHR (toggled by segmented control)
//
// Marks:
// 1. BarMark — x: month, y: value — fill colorExercise (kcal) or #0D9488 (HR)
// 2. For injury month: annotation diamond above bar — colorEventInjury
//
// Corner radius: 4pt
// Animation on metric change: .animation(.easeInOut, value: selectedMetric)
```

---

## State Management

Use a single `@StateObject HealthStore: ObservableObject` at app level, injected via `.environmentObject`.

```swift
class HealthStore: ObservableObject {
    @Published var events: [HealthEvent] = HealthEvent.mockData
    @Published var weightEntries: [WeightEntry] = WeightEntry.mockData
    @Published var sleepEntries: [SleepEntry] = SleepEntry.mockData
    @Published var exerciseMonths: [ExerciseMonth] = ExerciseMonth.mockData

    // Derived
    var latestWeight: Double { weightEntries.last?.kg ?? 0 }
    var goalWeight: Double = 73.0
    var distToGoal: Double { latestWeight - goalWeight }
    var progressPct: Double { ... }

    func addEvent(_ event: HealthEvent) {
        events.insert(event, at: 0)
    }
}
```

Per-screen local state (range selector, sheet visibility) stays `@State` inside the view.

---

## Mock Data

See `DataModels.swift` in this folder for Swift struct definitions and complete mock data matching the prototype exactly.

**Data summary:**
- Weight: 150+ weekly entries 2019–2026, monthly and yearly aggregations
- Sleep: 14 nightly entries (June 4–17, 2026), stage breakdown
- Exercise: 6 months kcal + avg HR (Jan–Jun 2026)
- Events: 4 pre-seeded (出差·上海, 饮酒·聚餐, 感冒发烧, 腰肌肉拉伤)

---

## Assets

No custom images. All icons use SF Symbols. Charts are rendered natively via Swift Charts.

---

## Files in This Bundle

| File | Description |
|---|---|
| `README.md` | This document — full design spec |
| `DataModels.swift` | Swift structs + mock data, ready to drop in |
| `健康App-高保真原型.html` | Interactive HTML prototype — open in browser for visual reference |

---

## Development Order (Recommended)

1. **Project scaffold** — App entry, `TabView`, `HealthStore`, color/font extensions
2. **WeightView** — Line chart + range picker + event markers (most complex chart)
3. **HomeView** — Aggregates from store, sparkline, event list
4. **SleepView** — Bar chart + stage breakdown
5. **ExerciseView** — Bar chart + metric toggle
6. **AddEventSheet** — Shared modal, type chips, save to store
7. **ProfileView** — Goal card + settings rows
8. **Apple Health integration** — Replace mock data with `HKHealthStore` queries
