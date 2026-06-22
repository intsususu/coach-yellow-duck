// EventTimelineView.swift
// E1 · 事件时间轴。PRD §5.7 / §4.2。
// 类型筛选 chips + 按月分组 + 单日/时间段展示；点击行进入 E2 编辑，右上＋ 新建。

import SwiftUI

struct EventTimelineView: View {
    @EnvironmentObject private var appState: AppState

    @State private var filter: EventType?          // nil = 全部
    @State private var editorMode: EditorMode?
    @State private var lastDeleted: HealthEvent?    // 最近删除的一条，供「撤销删除」恢复；退出页面即清空
    @State private var undoDismissTask: Task<Void, Never>?  // 删除后 3 秒自动隐藏「撤销删除」的计时

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterChips
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                eventList
            }
            .background(Color.appBg.ignoresSafeArea())
            .overlay(alignment: .bottom) { undoBanner }
            .onDisappear { undoDismissTask?.cancel(); lastDeleted = nil }
            .navigationTitle("事件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editorMode = .new } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 34, height: 34)
                            .foregroundColor(.white)
                            .background(Color.brandBlue)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("记录事件")
                }
            }
            .sheet(item: $editorMode) { mode in
                EventEditorView(event: mode.event)
            }
        }
    }

    // MARK: - 类型筛选

    private var filterOptions: [EventType?] { [nil, .illness, .travel, .drink, .other] }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(filterOptions.enumerated()), id: \.offset) { _, option in
                    filterChip(option)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func filterChip(_ option: EventType?) -> some View {
        let selected = option == filter
        let tint = option?.color ?? .brandBlue
        return Button {
            filter = option
        } label: {
            Text(option?.label ?? "全部")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .foregroundColor(selected ? .white : tint)
                .background(selected ? tint : tint.opacity(0.1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 分组

    private var filteredEvents: [HealthEvent] {
        appState.events
            .filter { filter == nil || $0.type == filter }
            .sorted { $0.startDate > $1.startDate }
    }

    private var groupedEvents: [(key: String, title: String, events: [HealthEvent])] {
        let calendar = Calendar(identifier: .gregorian)
        let grouped = Dictionary(grouping: filteredEvents) { event in
            calendar.dateComponents([.year, .month], from: event.startDate)
        }
        return grouped
            .map { components, events -> (key: String, title: String, events: [HealthEvent]) in
                let year = components.year ?? 0
                let month = components.month ?? 0
                return (key: String(format: "%04d-%02d", year, month),
                        title: "\(year) 年 \(month) 月",
                        events: events)
            }
            .sorted { $0.key > $1.key }
    }

    // MARK: - 列表（原生 List + swipeActions，天然兼容竖向滚动与 sheet 下拉关闭）

    @ViewBuilder
    private var eventList: some View {
        if groupedEvents.isEmpty {
            // 空态也放进可滚动容器，保证此页同样能下拉关闭 sheet。
            ScrollView { emptyState.padding(.top, 40) }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(groupedEvents, id: \.key) { group in
                    Section {
                        ForEach(group.events, id: \.id) { event in
                            eventRow(event)
                        }
                    } header: {
                        Text(group.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.textSecondary)
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)   // 隐藏 List 默认灰底，露出 appBg
        }
    }

    /// 单行：整行点按进编辑，左滑用原生 swipeActions 删除（红色「删除」，支持整滑）。
    private func eventRow(_ event: HealthEvent) -> some View {
        Button { editorMode = .edit(event) } label: {
            EventTimelineRow(event: event)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.cardBg)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                delete(event)
            } label: {
                Label("删除", systemImage: "trash")
            }
            .tint(.red)
        }
    }

    // MARK: - 删除与撤销

    private func delete(_ event: HealthEvent) {
        withAnimation(.easeInOut(duration: 0.2)) {
            lastDeleted = event
        }
        Task { await appState.deleteEvent(event) }
        // 3 秒后自动收起「撤销删除」；新一次删除会取消上一次计时。
        undoDismissTask?.cancel()
        undoDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { lastDeleted = nil }
        }
    }

    @ViewBuilder
    private var undoBanner: some View {
        if let deleted = lastDeleted {
            Button {
                undoDismissTask?.cancel()
                withAnimation { lastDeleted = nil }
                Task { await appState.restoreEvent(deleted) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 12, weight: .bold))
                    Text("撤销删除")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.textPrimary.opacity(0.9)))
                .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 28)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 34))
                .foregroundColor(.textMuted)
            Text("还没有这类事件")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.textPrimary)
            Text("点击右上角＋记录特殊事件")
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }
}

extension EventTimelineView {
    enum EditorMode: Identifiable {
        case new
        case edit(HealthEvent)

        var id: String {
            switch self {
            case .new: return "new"
            case .edit(let event): return event.id
            }
        }

        var event: HealthEvent? {
            switch self {
            case .new: return nil
            case .edit(let event): return event
            }
        }
    }
}

// MARK: - 时间轴行

private struct EventTimelineRow: View {
    let event: HealthEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(event.type.color)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(event.type.color.opacity(0.2), lineWidth: 4))
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 4) {
                FlowLayout(spacing: 6) {
                    Text(event.type.label)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                        .padding(.trailing, 2)
                    ForEach(event.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .foregroundColor(event.type.color)
                            .background(event.type.backgroundColor)
                            .clipShape(Capsule())
                    }
                }
                Text(Self.dateText(for: event))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
                if !event.note.isEmpty {
                    Text(event.note)
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textMuted)
                .padding(.top, 4)
        }
        .padding(14)
        .contentShape(Rectangle())
    }

    // MARK: - 日期文案

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f
    }()

    private static let endDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "d日"
        return f
    }()

    static func dateText(for event: HealthEvent) -> String {
        let start = dayFormatter.string(from: event.startDate)
        guard let end = event.endDate else { return start }
        // 跨月（或跨年）的结束日要带上月份，避免「4月26日–2日」丢掉「5月」。
        let sameMonth = Calendar(identifier: .gregorian)
            .isDate(event.startDate, equalTo: end, toGranularity: .month)
        let endText = (sameMonth ? endDayFormatter : dayFormatter).string(from: end)
        return "\(start)–\(endText) · \(dayCount(from: event.startDate, to: end))天"
    }

    private static func dayCount(from start: Date, to end: Date) -> Int {
        let calendar = Calendar(identifier: .gregorian)
        let from = calendar.startOfDay(for: start)
        let to = calendar.startOfDay(for: end)
        return (calendar.dateComponents([.day], from: from, to: to).day ?? 0) + 1
    }
}
