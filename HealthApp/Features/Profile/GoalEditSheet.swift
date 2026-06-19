// GoalEditSheet.swift
// 目标体重编辑：暂存输入，保存后由 ProfileView 写回 AppState。

import SwiftUI

struct GoalEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draftWeight: Double
    let onSave: (Double) -> Void

    init(goalWeight: Double, onSave: @escaping (Double) -> Void) {
        _draftWeight = State(initialValue: goalWeight)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("设定你的目标")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(.textPrimary)
                    Text("目标会同步更新首页距离与体重趋势线")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textSecondary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(String(format: "%.1f", draftWeight))
                        .font(.system(size: 44, weight: .heavy))
                        .foregroundColor(.brandBlue)
                    Text("kg")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.brandBlue.opacity(0.7))
                }

                Stepper(value: $draftWeight, in: 40...150, step: 0.5) {
                    Text("每次调整 0.5kg")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textPrimary)
                }
                .padding(14)
                .background(Color.weightCardBg)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button {
                    onSave(draftWeight.rounded(toPlaces: 1))
                    dismiss()
                } label: {
                    Text("保存目标")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.brandBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(20)
            .background(Color.appBg.ignoresSafeArea())
            .navigationTitle("编辑目标体重")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
