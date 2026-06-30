// EventEditorView.swift
// E2 · 添加 / 编辑事件全局弹窗。PRD §5.8 / §4.2。
// event == nil 为新建；否则编辑既有事件（复用 id，保存即原地更新）。

import SwiftUI

struct EventEditorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private let editingEvent: HealthEvent?

    @StateObject private var tagStore = EventTagStore()

    @State private var type: EventType
    @State private var isPeriod: Bool
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var note: String
    @State private var selectedTags: [String]
    @State private var isSaving = false
    @State private var isAddingTag = false
    @State private var newTagText = ""

    init(event: HealthEvent? = nil) {
        self.editingEvent = event
        let defaultDate = Self.defaultDate
        _type = State(initialValue: event?.type ?? .illness)
        _isPeriod = State(initialValue: event?.isPeriod ?? false)
        _startDate = State(initialValue: event?.startDate ?? defaultDate)
        _endDate = State(initialValue: event?.endDate ?? event?.startDate ?? defaultDate)
        _note = State(initialValue: event?.note ?? "")
        _selectedTags = State(initialValue: event?.tags ?? [])
    }

    private static var defaultDate: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var isEditing: Bool { editingEvent != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    typeSection
                    tagSection
                    durationSection
                    dateSection
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
            // 标签按类型归类，切换类型时清空已选，避免残留与新类型无关的标签。
            .onChange(of: type) { _ in selectedTags = [] }
            .alert("新增标签", isPresented: $isAddingTag) {
                TextField("标签名称", text: $newTagText)
                Button("取消", role: .cancel) { }
                Button("添加") { addCustomTag() }
            } message: {
                Text("为「\(type.label)」添加一个自定义标签")
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

    // MARK: - 标签

    private var tagSection: some View {
        fieldGroup(title: "标签") {
            FlowLayout(spacing: 8) {
                ForEach(tagStore.tags(for: type), id: \.self) { tag in
                    tagChip(tag)
                }
                addTagChip
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func tagChip(_ tag: String) -> some View {
        let selected = selectedTags.contains(tag)
        return Button {
            if let index = selectedTags.firstIndex(of: tag) {
                selectedTags.remove(at: index)
            } else {
                selectedTags.append(tag)
            }
        } label: {
            Text(tag)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundColor(selected ? .white : type.color)
                .background(selected ? type.color : type.backgroundColor)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: selected)
    }

    private var addTagChip: some View {
        Button {
            newTagText = ""
            isAddingTag = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text("添加")
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundColor(.textSecondary)
            .overlay(
                Capsule().stroke(Color.textMuted.opacity(0.4),
                                 style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
        }
        .buttonStyle(.plain)
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
            DateRangePickerSection(isPeriod: isPeriod,
                                   startDate: $startDate,
                                   endDate: $endDate,
                                   calendar: calendar,
                                   autoExtendsEndDate: true)
        }
    }

    // MARK: - 备注

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

    // MARK: - 标签新增

    private func addCustomTag() {
        let tag = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        tagStore.addTag(tag, for: type)
        if !selectedTags.contains(tag) { selectedTags.append(tag) }
        newTagText = ""
    }

    // MARK: - 保存

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        // 只保存当前类型仍可用的标签，避免切换类型后残留无关标签。
        let available = tagStore.tags(for: type)
        let event = HealthEvent(
            id: editingEvent?.id ?? UUID().uuidString,
            type: type,
            startDate: startDate,
            endDate: isPeriod ? max(endDate, startDate) : nil,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: selectedTags.filter { available.contains($0) }
        )
        Task {
            await appState.saveEvent(event)
            dismiss()
        }
    }
}

// MARK: - 自动换行流式布局

/// 标签等元素从左到右排布，超出宽度自动换行。iOS 16+ Layout 协议实现。
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(maxWidth: maxWidth, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let rows = computeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                let size = subviews[item].sizeThatFits(.unspecified)
                subviews[item].place(at: CGPoint(x: x, y: y),
                                     anchor: .topLeading,
                                     proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var items: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.items.isEmpty ? size.width : current.width + spacing + size.width
            if needed > maxWidth, !current.items.isEmpty {
                rows.append(current)
                current = Row()
            }
            if current.items.isEmpty {
                current.width = size.width
            } else {
                current.width += spacing + size.width
            }
            current.items.append(index)
            current.height = max(current.height, size.height)
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}
