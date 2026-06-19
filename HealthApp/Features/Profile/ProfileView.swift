// ProfileView.swift
// 用户画像、目标体重与设置入口。PRD §5.5。

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showsGoalEditor = false
    @State private var currentWeight: Double?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    profileHeader
                    goalCard
                    dataSettings
                    appSettings
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.appBg.ignoresSafeArea())
            .navigationTitle("我的")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { appState.presentEventEditor() } label: {
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
            .sheet(isPresented: $showsGoalEditor) {
                GoalEditSheet(goalWeight: appState.goalWeight) { newGoal in
                    appState.goalWeight = newGoal
                    appState.showToast("目标体重已更新")
                }
                .presentationDetents([.medium])
            }
            .task {
                let samples = await appState.repository.weightSeries(range: .week)
                currentWeight = samples.last?.kg.rounded(toPlaces: 1)
            }
        }
    }

    private var profileHeader: some View {
        CardView {
            HStack(spacing: 14) {
                Text("李")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(
                        LinearGradient(colors: [.brandBlue, .sleepIndigo],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                    )
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("李 · 减脂中")
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundColor(.textPrimary)
                    Text("178cm · 34 岁 · 男")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textSecondary)
                    Label("已连接 Apple 健康", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.successGreen)
                }
                Spacer()
            }
        }
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("目标体重")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Button("编辑") { showsGoalEditor = true }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.brandBlue)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(Color.brandBlue.opacity(0.1))
                    .clipShape(Capsule())
            }

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(String(format: "%.1f", appState.goalWeight))
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundColor(.brandBlue)
                Text("kg")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.brandBlue.opacity(0.7))
                Spacer()
                Text(distanceText)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.successGreen)
            }

            ProgressView(value: goalProgress)
                .tint(.brandBlue)
                .scaleEffect(x: 1, y: 1.6, anchor: .center)
        }
        .padding(16)
        .background(Color.weightCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.brandBlue.opacity(0.18), lineWidth: 1)
        )
    }

    private var dataSettings: some View {
        settingsGroup(title: "数据与偏好") {
            settingRow(icon: "heart.text.square.fill", title: "数据来源", value: "Apple 健康 ✓", tint: .successGreen) {
                appState.presentHealthImport()
            }
            settingDivider
            settingRow(icon: "scalemass.fill", title: "单位", value: "公斤(kg) ›", tint: .brandBlue) {
                placeholderToast("单位设置")
            }
            settingDivider
            settingRow(icon: "bell.fill", title: "每日提醒", value: "8:00 ›", tint: .exerciseOrange) {
                placeholderToast("提醒设置")
            }
        }
    }

    private var appSettings: some View {
        settingsGroup(title: "更多") {
            settingRow(icon: "plus.circle.fill", title: "记录特殊事件", value: "生病/损伤/饮酒/旅行 ›", tint: .brandBlue) {
                appState.presentEventEditor()
            }
            settingDivider
            settingRow(icon: "square.and.arrow.up.fill", title: "导出数据", value: "›", tint: .eventTravel) {
                placeholderToast("数据导出")
            }
            settingDivider
            settingRow(icon: "lock.shield.fill", title: "隐私与安全", value: "本机存储 ›", tint: .successGreen) {
                placeholderToast("隐私与安全")
            }
            settingDivider
            settingRow(icon: "info.circle.fill", title: "关于", value: "v1.0 ›", tint: .textSecondary) {
                placeholderToast("关于")
            }
        }
    }

    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.textSecondary)
                .padding(.leading, 4)
            CardView(padding: 0) {
                VStack(spacing: 0) { content() }
            }
        }
    }

    private func settingRow(icon: String,
                            title: String,
                            value: String,
                            tint: Color,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private var settingDivider: some View {
        Divider()
            .background(Color.hairline)
            .padding(.leading, 60)
    }

    private var distanceText: String {
        guard let currentWeight else { return "计算中" }
        let distance = (currentWeight - appState.goalWeight).rounded(toPlaces: 1)
        return distance > 0 ? "还差 \(String(format: "%.1f", distance))kg" : "目标已达成"
    }

    private var goalProgress: Double {
        guard let currentWeight else { return 0 }
        let startWeight = HomeMetricContract.startWeight
        let denominator = max(startWeight - appState.goalWeight, 0.1)
        return max(0, min(1, (startWeight - currentWeight) / denominator))
    }

    private func placeholderToast(_ title: String) {
        appState.showToast("\(title)将在后续版本开放")
    }
}
