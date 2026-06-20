// EventEditorView.swift
// E2 · 添加 / 编辑事件全局弹窗。PRD §5.8 / §4.2。
// event == nil 为新建；否则编辑既有事件（复用 id，保存即原地更新）。

import SwiftUI

struct EventEditorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private let editingEvent: HealthEvent?

    @State private var type: EventType
    @State private var isPeriod: Bool
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var title: String
    @State private var note: String
    @State private var isSaving = false

    init(event: HealthEvent? = nil) {
        self.editingEvent = event
        let defaultDate = HealthEvent.date("2026-06-18")
        _type = State(initialValue: event?.type ?? .illness)
        _isPeriod = State(initialValue: event?.isPeriod ?? false)
        _startDate = State(initialValue: event?.startDate ?? defaultDate)
        _endDate = State(initialValue: event?.endDate ?? event?.startDate ?? defaultDate)
        _title = State(initialValue: event?.title ?? "")
        _note = State(initialValue: event?.note ?? "")
    }

    private var isEditing: Bool { editingEvent != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    typeSection
                    durationSection
                    dateSection
                    titleSection
                    noteSection
                    hintBanner
                }
                .padding(16)
            }
            .background(Color.appBg.ignoresSafeArea())
            .navigationTitle(isEditing ? "编辑事件" : "新建事件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .tint(.brandBlue)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }
                        .font(.system(size: 15, weight: .bold))
                        .tint(.brandBlue)
                        .disabled(isSaving)
                }
            }
        }
        // 注意：不要在此覆盖 \.calendar / \.locale 环境。覆盖后 compact DatePicker 的
        // 日历弹层在点选日期时不会自动收起（提交用的是覆盖日历，收起触发器却不触发）。
        // 中文界面靠设备本地化即可；日期天数计算用显式 localizedCalendar（见 EventDateSection）。
    }

    // MARK: - 类型

    private var typeSection: some View {
        fieldGroup(title: "类型") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                      spacing: 10) {
                ForEach(EventType.allCases, id: \.self) { option in
                    typeChip(option)
                }
            }
        }
    }

    private func typeChip(_ option: EventType) -> some View {
        let selected = option == type
        return Button {
            type = option
        } label: {
            HStack(spacing: 6) {
                Image(systemName: option.sfSymbol)
                    .font(.system(size: 13, weight: .semibold))
                Text(option.label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundColor(selected ? .white : option.color)
            .background(selected ? option.color : option.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(option.color.opacity(selected ? 0 : 0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: type)
    }

    // MARK: - 持续切换

    private var durationSection: some View {
        fieldGroup(title: "持续时间") {
            Picker("持续时间", selection: $isPeriod) {
                Text("单日").tag(false)
                Text("时间段").tag(true)
            }
            .pickerStyle(.segmented)
            .onChange(of: isPeriod) { isPeriod in
                // 切到「时间段」时才把结束日对齐到不早于开始日；单日模式无需维护结束日。
                if isPeriod, endDate < startDate { endDate = startDate }
            }
        }
    }

    // MARK: - 日期

    private static let localizedCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh-Hans-CN")
        return calendar
    }()

    private var calendar: Calendar { Self.localizedCalendar }

    private var dateSection: some View {
        fieldGroup(title: isPeriod ? "起止日期" : "日期") {
            EventDateSection(isPeriod: isPeriod,
                             startDate: $startDate,
                             endDate: $endDate,
                             calendar: calendar)
        }
    }

    // MARK: - 标题 / 备注

    private var titleSection: some View {
        fieldGroup(title: "标题（可选）") {
            TextField(type.label, text: $title)
                .font(.system(size: 15))
                .foregroundColor(.textPrimary)
        }
    }

    private var noteSection: some View {
        fieldGroup(title: "备注") {
            TextField("添加描述，例如“感冒发烧，停训”…", text: $note, axis: .vertical)
                .font(.system(size: 15))
                .foregroundColor(.textPrimary)
                .lineLimit(3...6)
        }
    }

    private var hintBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 13))
                .foregroundColor(.brandBlue)
            Text("记录后会在体重/睡眠/运动图表上标注，帮你解释数据波动。")
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandBlue.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 组件

    private func fieldGroup<Content: View>(title: String,
                                           @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.textSecondary)
                .padding(.leading, 4)
            CardView { content() }
        }
    }

    // MARK: - 保存

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let event = HealthEvent(
            id: editingEvent?.id ?? UUID().uuidString,
            type: type,
            title: trimmedTitle.isEmpty ? type.label : trimmedTitle,
            startDate: startDate,
            endDate: isPeriod ? max(endDate, startDate) : nil,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        Task {
            await appState.saveEvent(event)
            dismiss()
        }
    }
}

// MARK: - 日期区子视图

/// 独立出来的日期选择区，避免标题和备注的输入状态干扰 DatePicker。
private struct EventDateSection: View {
    private enum ActiveDateField {
        case start
        case end
    }

    let isPeriod: Bool
    @Binding var startDate: Date
    @Binding var endDate: Date
    let calendar: Calendar

    @State private var activeField: ActiveDateField?

    private static let slashFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            if isPeriod {
                dateRow("开始日期", date: startDate, field: .start)
                    .onChange(of: startDate) { newValue in
                        if endDate < newValue { endDate = newValue }
                    }
                if activeField == .start {
                    CustomDateWheel(selection: $startDate,
                                    calendar: calendar,
                                    onDayConfirmed: collapseDateWheel)
                        .transition(dateWheelTransition)
                }
                Divider().background(Color.hairline)
                dateRow("结束日期", date: endDate, field: .end)
                if activeField == .end {
                    CustomDateWheel(selection: $endDate,
                                    minimumDate: startDate,
                                    calendar: calendar,
                                    onDayConfirmed: collapseDateWheel)
                        .transition(dateWheelTransition)
                }
                Divider().background(Color.hairline)
                HStack {
                    Text("持续天数")
                    Spacer()
                    Text("共 \(periodDayCount) 天")
                        .fontWeight(.semibold)
                        .foregroundColor(.brandBlue)
                }
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
                .padding(.vertical, 10)
            } else {
                dateRow("选择日期", date: startDate, field: .start)
                if activeField == .start {
                    CustomDateWheel(selection: $startDate,
                                    calendar: calendar,
                                    onDayConfirmed: collapseDateWheel)
                        .transition(dateWheelTransition)
                }
            }
        }
        .animation(.easeInOut(duration: 0.24), value: activeField)
        .onChange(of: isPeriod) { _ in
            activeField = nil
        }
    }

    private func dateRow(_ label: String, date: Date, field: ActiveDateField) -> some View {
        Button {
            activeField = activeField == field ? nil : field
        } label: {
            HStack(spacing: 12) {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                Spacer()
                Text(Self.slashFormatter.string(from: date))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Image(systemName: activeField == field ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textMuted)
                    .frame(width: 16)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .background(activeField == field ? Color.brandBlue.opacity(0.08) : Color.appBg)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(Self.slashFormatter.string(from: date))
        .accessibilityHint(activeField == field ? "点击收起日历" : "点击展开日历")
    }

    private func collapseDateWheel() {
        withAnimation(.easeInOut(duration: 0.24)) {
            activeField = nil
        }
    }

    /// 以顶部为锚点在自身区域内展开，避免轮盘穿过上方的日期行。
    private var dateWheelTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.97, anchor: .top)),
            removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
        )
    }

    private var periodDayCount: Int {
        let from = calendar.startOfDay(for: startDate)
        let to = calendar.startOfDay(for: endDate)
        return (calendar.dateComponents([.day], from: from, to: to).day ?? 0) + 1
    }
}

/// 系统 DatePicker 不支持自定义轮盘列顺序和单个日期颜色，因此用三列 Picker 组合。
private struct CustomDateWheel: View {
    @Binding var selection: Date
    var minimumDate: Date? = nil
    let calendar: Calendar
    let onDayConfirmed: () -> Void

    private var selectedYear: Int { calendar.component(.year, from: selection) }
    private var selectedMonth: Int { calendar.component(.month, from: selection) }
    private var selectedDay: Int { calendar.component(.day, from: selection) }

    private var minimumComponents: DateComponents? {
        guard let minimumDate else { return nil }
        return calendar.dateComponents([.year, .month, .day], from: minimumDate)
    }

    private var years: ClosedRange<Int> {
        let lowerYear = minimumComponents?.year ?? min(1900, selectedYear)
        return lowerYear...max(2100, selectedYear)
    }

    private var months: ClosedRange<Int> {
        guard selectedYear == minimumComponents?.year,
              let minimumMonth = minimumComponents?.month else {
            return 1...12
        }
        return minimumMonth...12
    }

    private var days: ClosedRange<Int> {
        let firstDay: Int
        if selectedYear == minimumComponents?.year,
           selectedMonth == minimumComponents?.month,
           let minimumDay = minimumComponents?.day {
            firstDay = minimumDay
        } else {
            firstDay = 1
        }
        return firstDay...numberOfDays(year: selectedYear, month: selectedMonth)
    }

    var body: some View {
        HStack(spacing: 0) {
            Picker("年", selection: yearBinding) {
                ForEach(years, id: \.self) { year in
                    Text("\(year)年").tag(year)
                }
            }
            .frame(maxWidth: .infinity)

            Picker("月", selection: monthBinding) {
                ForEach(months, id: \.self) { month in
                    Text("\(month)月").tag(month)
                }
            }
            .frame(maxWidth: .infinity)

            Picker("日", selection: dayBinding) {
                ForEach(days, id: \.self) { day in
                    Text("\(day)日")
                        .foregroundColor(isWeekend(day: day) ? Color.brandBlue.opacity(0.55) : .textPrimary)
                        .tag(day)
                }
            }
            .frame(maxWidth: .infinity)
            .simultaneousGesture(
                TapGesture().onEnded {
                    // 让 Picker 先提交点击的日期，再收起轮盘。拖动手势不会触发。
                    DispatchQueue.main.async {
                        onDayConfirmed()
                    }
                }
            )
        }
        .pickerStyle(.wheel)
        .frame(height: 190)
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("日期轮盘")
    }

    private var yearBinding: Binding<Int> {
        Binding(get: { selectedYear }, set: { update(year: $0) })
    }

    private var monthBinding: Binding<Int> {
        Binding(get: { selectedMonth }, set: { update(month: $0) })
    }

    private var dayBinding: Binding<Int> {
        Binding(get: { selectedDay }, set: { update(day: $0) })
    }

    private func update(year: Int? = nil, month: Int? = nil, day: Int? = nil) {
        let newYear = year ?? selectedYear
        var newMonth = month ?? selectedMonth
        var newDay = day ?? selectedDay

        if let minimum = minimumComponents,
           let minimumYear = minimum.year,
           let minimumMonth = minimum.month,
           newYear == minimumYear {
            newMonth = max(newMonth, minimumMonth)
            if newMonth == minimumMonth, let minimumDay = minimum.day {
                newDay = max(newDay, minimumDay)
            }
        }

        newDay = min(newDay, numberOfDays(year: newYear, month: newMonth))
        let components = DateComponents(year: newYear, month: newMonth, day: newDay)
        guard var newDate = calendar.date(from: components) else { return }

        if let minimumDate, newDate < calendar.startOfDay(for: minimumDate) {
            newDate = calendar.startOfDay(for: minimumDate)
        }
        selection = newDate
    }

    private func numberOfDays(year: Int, month: Int) -> Int {
        let components = DateComponents(year: year, month: month, day: 1)
        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return 31
        }
        return range.count
    }

    private func isWeekend(day: Int) -> Bool {
        let components = DateComponents(year: selectedYear, month: selectedMonth, day: day)
        guard let date = calendar.date(from: components) else { return false }
        return calendar.isDateInWeekend(date)
    }
}
