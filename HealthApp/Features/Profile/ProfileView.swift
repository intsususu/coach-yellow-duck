// ProfileView.swift
// 「我的」：沉浸式头像头部 + 目标体重 + 数据与偏好 + 隐私与安全 + 关于。PRD §5.5。
// 头像吸色驱动顶部沉浸式渐变；资料/头像由 ProfileStore 本地持久化。

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var store = ProfileStore()

    @State private var showsProfileEditor = false
    @State private var showsGoalEditor = false
    @State private var showsEventTimeline = false
    @State private var showsAbout = false
    @State private var showsHealthImport = false
    @State private var currentWeight: Double?

    /// 沉浸式渐变高度：顶部主色渐隐到页面底色，约过渡到屏幕中部。
    private let immersiveHeight: CGFloat = 360

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.appBg.ignoresSafeArea()

                LinearGradient(
                    colors: [store.headerTint, store.headerTint.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: immersiveHeight)
                .frame(maxWidth: .infinity)
                .ignoresSafeArea(edges: .top)

                ScrollView {
                    VStack(spacing: 14) {
                        profileHeader
                        goalCard
                        dataSettings
                        privacySettings
                        aboutSettings
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showsProfileEditor) {
                ProfileEditView(store: store)
            }
            .sheet(isPresented: $showsGoalEditor) {
                GoalEditSheet(goalWeight: appState.goalWeight) { newGoal in
                    appState.goalWeight = newGoal
                    appState.showToast("目标体重已更新")
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showsEventTimeline) {
                EventTimelineView()
            }
            .sheet(isPresented: $showsAbout) {
                AboutView()
            }
            .navigationDestination(isPresented: $showsHealthImport) {
                // 管理页：可经系统返回按钮与左缘右滑返回；再次点击连接按钮跳转系统设置管理权限。
                ImportView(isOnboarding: false)
            }
            .task {
                let samples = await appState.repository.weightSeries(range: .week)
                currentWeight = samples.last?.kg.rounded(toPlaces: 1)
            }
        }
    }

    // MARK: - 沉浸式头部

    private var profileHeader: some View {
        VStack(spacing: 12) {
            // 顶部右侧设置入口
            HStack {
                Spacer()
                Button { showsProfileEditor = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.textPrimary.opacity(0.7))
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }

            Button { showsProfileEditor = true } label: {
                AvatarImageView(image: store.avatarImage, size: 96)
            }
            .buttonStyle(.plain)

            VStack(spacing: 5) {
                Text(store.profile.headline)
                    .font(.system(size: 21, weight: .heavy))
                    .foregroundColor(.textPrimary)
                Text(store.profile.detailLine)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textSecondary)
                Label(connectionLabel, systemImage: connectionIcon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(connectionTint)
                    .padding(.top, 2)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    // MARK: - 目标体重（沿用原模块）

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
                    .foregroundColor(.weightGreen)
                Text("kg")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.weightGreen.opacity(0.7))
                Spacer()
                Text(distanceText)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.successGreen)
            }

            ProgressView(value: goalProgress)
                .tint(.weightGreen)
                .scaleEffect(x: 1, y: 1.6, anchor: .center)
        }
        .padding(16)
        .background(Color.weightCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.weightGreen.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - 数据与偏好

    private var dataSettings: some View {
        settingsGroup(title: "数据与偏好") {
            settingRow(icon: "heart.text.square.fill", title: "数据来源", value: dataSourceValue, tint: connectionTint) {
                #if targetEnvironment(simulator)
                appState.showToast("模拟器：当前使用模拟数据")
                #else
                showsHealthImport = true
                #endif
            }
            settingDivider
            settingRow(icon: "square.and.arrow.down.fill", title: "体测数据导入", value: "暂未开放 ›", tint: .eventTravel) {
                placeholderToast("体测数据导入")
            }
            settingDivider
            settingRow(icon: "calendar.badge.clock", title: "事件管理", value: "伤病/出行/饮酒/其他 ›", tint: .brandBlue) {
                showsEventTimeline = true
            }
        }
    }

    // MARK: - 隐私与安全（存储位置，当前仅记录偏好）

    private var privacySettings: some View {
        settingsGroup(title: "隐私与安全") {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.successGreen)
                    .frame(width: 34, height: 34)
                    .background(Color.successGreen.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text("数据存储")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Picker("存储位置", selection: $store.storageLocation) {
                    ForEach(StorageLocation.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 168)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .onChange(of: store.storageLocation) { _, loc in
                if loc == .iCloud {
                    appState.showToast("iCloud 同步将在后续版本开放")
                }
            }

            settingDivider
            Text(store.storageLocation == .local
                 ? "数据仅保存在本机，不会上传。"
                 : "iCloud 同步暂未开放，当前仍保存在本机。")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
    }

    // MARK: - 关于

    private var aboutSettings: some View {
        settingsGroup(title: "关于") {
            settingRow(icon: "info.circle.fill", title: "关于自律小黄鸡", value: "v1.0 ›", tint: .textSecondary) {
                showsAbout = true
            }
        }
    }

    // MARK: - 复用行 / 分组

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

    // MARK: - 数据来源展示（模拟器标注 mock，真机显示已连接 Apple 健康）

    private var connectionLabel: String {
        AppConfig.useMockData ? "模拟器 · 模拟数据" : "已连接 Apple 健康"
    }

    private var connectionIcon: String {
        AppConfig.useMockData ? "ladybug.fill" : "checkmark.circle.fill"
    }

    private var connectionTint: Color {
        AppConfig.useMockData ? .exerciseOrange : .successGreen
    }

    private var dataSourceValue: String {
        AppConfig.useMockData ? "模拟数据 · 模拟器" : "Apple 健康 ✓"
    }
}
