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

    // 日期区拆成独立 Equatable 子视图：标题/备注输入不再每次按键都重绘内嵌的
    // UIKit DatePicker，缓解呼出输入法时的卡顿。
    private var dateSection: some View {
        fieldGroup(title: isPeriod ? "起止日期" : "日期") {
            EventDateSection(isPeriod: isPeriod,
                             startDate: $startDate,
                             endDate: $endDate,
                             calendar: calendar)
                .equatable()
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
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let event = HealthEvent(
            id: editingEvent?.id ?? UUID().uuidString,
            type: type,
            title: trimmedTitle.isEmpty ? type.label : trimmedTitle,
            startDate: startDate,
            endDate: isPeriod ? max(endDate, startDate) : nil,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        Task { await appState.saveEvent(event) }
        dismiss()
    }
}

// MARK: - 日期区子视图

/// 独立出来的日期选择区。声明为 `Equatable`，配合 `.equatable()` 让父视图在标题/备注
/// 等无关状态变化时跳过本区重绘——内嵌的 compact `DatePicker` 桥接 UIKit，重绘代价高，
/// 频繁重建正是输入法卡顿与（早期版本）日期弹层不消失的诱因。
private struct EventDateSection: View, Equatable {
    let isPeriod: Bool
    @Binding var startDate: Date
    @Binding var endDate: Date
    let calendar: Calendar

    // 仅按值比较，忽略 Binding：标题/备注变化时三项不变即跳过重绘。
    static func == (lhs: EventDateSection, rhs: EventDateSection) -> Bool {
        lhs.isPeriod == rhs.isPeriod &&
        lhs.startDate == rhs.startDate &&
        lhs.endDate == rhs.endDate
    }

    var body: some View {
        VStack(spacing: 0) {
            if isPeriod {
                compactDatePicker("开始日期", selection: $startDate)
                    .onChange(of: startDate) { newValue in
                        if endDate < newValue { endDate = newValue }
                    }
                Divider().background(Color.hairline)
                compactDatePicker("结束日期", selection: $endDate, in: startDate...)
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
                // 单日模式不维护结束日，避免选日期时的额外状态写入打断弹层关闭。
                compactDatePicker("选择日期", selection: $startDate)
            }
        }
    }

    private func compactDatePicker(_ label: String,
                                   selection: Binding<Date>) -> some View {
        DatePicker(selection: selection, displayedComponents: .date) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
        }
        .datePickerStyle(.compact)
        .tint(.brandBlue)
        .padding(.vertical, 8)
    }

    private func compactDatePicker(_ label: String,
                                   selection: Binding<Date>,
                                   in range: PartialRangeFrom<Date>) -> some View {
        DatePicker(selection: selection, in: range, displayedComponents: .date) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
        }
        .datePickerStyle(.compact)
        .tint(.brandBlue)
        .padding(.vertical, 8)
    }

    private var periodDayCount: Int {
        let from = calendar.startOfDay(for: startDate)
        let to = calendar.startOfDay(for: endDate)
        return (calendar.dateComponents([.day], from: from, to: to).day ?? 0) + 1
    }
}
