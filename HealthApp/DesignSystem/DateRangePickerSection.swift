// DateRangePickerSection.swift
// 事件录入与综合分析共用的日期选择规范：日期行 + 年/月/日三列轮盘。

import SwiftUI

struct DateRangePickerSection: View {
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
                    .onChange(of: startDate) { _, newValue in
                        if endDate < newValue { endDate = newValue }
                    }
                if activeField == .start {
                    DateWheelPicker(selection: $startDate,
                                    calendar: calendar,
                                    onDayConfirmed: collapseDateWheel)
                        .transition(dateWheelTransition)
                }
                Divider().background(Color.hairline)
                dateRow("结束日期", date: endDate, field: .end)
                if activeField == .end {
                    DateWheelPicker(selection: $endDate,
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
                    DateWheelPicker(selection: $startDate,
                                    calendar: calendar,
                                    onDayConfirmed: collapseDateWheel)
                        .transition(dateWheelTransition)
                }
            }
        }
        .animation(.easeInOut(duration: 0.24), value: activeField)
        .onChange(of: isPeriod) { _, _ in
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

private struct DateWheelPicker: View {
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
