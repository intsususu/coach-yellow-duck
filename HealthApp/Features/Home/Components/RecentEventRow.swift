// RecentEventRow.swift
// 近期事件列表行：类型图标 + 类型名 + 日期（单日/时间段）；下一行灰色小字显示备注。
// 不论是否有备注，每行高度恒定（无备注时第二行用占位空格撑开）。

import SwiftUI

struct RecentEventRow: View {
    let event: HealthEvent

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: event.type.sfSymbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(event.type.color)
                .frame(width: 34, height: 34)
                .background(Circle().fill(event.type.color.opacity(0.16)))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(event.type.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    // 标签紧跟类型名；首页空间有限，最多内联展示前 2 个，完整标签见事件列表页。
                    ForEach(event.tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .foregroundColor(event.type.color)
                            .background(event.type.backgroundColor)
                            .clipShape(Capsule())
                            .lineLimit(1)
                    }
                    Text(Self.dateText(for: event))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
                // 备注最多 2 行；无备注时用空格占位。固定预留 2 行高度，保证各行等高。
                Text(event.note.isEmpty ? " " : event.note)
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)
            }

            Spacer(minLength: 0)
        }
        .frame(height: 56)
    }

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
        return "\(start)–\(endText)"
    }
}
