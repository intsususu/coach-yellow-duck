// ImportView.swift
// A3 Apple 健康授权与首次同步引导。

import SwiftUI

struct ImportView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    steps
                    privacyNote
                    actions
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
            }
            .background(Color.appBg.ignoresSafeArea())
            .navigationTitle("导入健康数据")
            .navigationBarTitleDisplayMode(.inline)
            .alert("连接失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "请稍后重试")
            }
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 86, height: 86)
                .background(
                    LinearGradient(colors: [.eventIllness, .exerciseOrange],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.eventIllness.opacity(0.2), radius: 14, x: 0, y: 7)

            Text("连接 Apple 健康")
                .font(.system(size: 26, weight: .heavy))
                .foregroundColor(.textPrimary)
            Text("把散落的体重、睡眠与运动记录，变成清晰的趋势和关联分析。")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var steps: some View {
        VStack(spacing: 12) {
            importStep(number: "1", icon: "checkmark.shield.fill", title: "授权读取权限",
                       detail: "体重 · 睡眠 · 运动 · 心率", tint: .brandBlue)
            importStep(number: "2", icon: "arrow.triangle.2.circlepath", title: "同步历史数据",
                       detail: "首次导入约 2019 年至今", tint: .sleepIndigo)
            importStep(number: "3", icon: "chart.xyaxis.line", title: "生成分析报告",
                       detail: "趋势 · 关联 · 建议", tint: .exerciseOrange)
        }
    }

    private func importStep(number: String,
                            icon: String,
                            title: String,
                            detail: String,
                            tint: Color) -> some View {
        CardView {
            HStack(spacing: 14) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(tint)
                        .frame(width: 48, height: 48)
                        .background(tint.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Text(number)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(tint)
                        .clipShape(Circle())
                        .offset(x: 5, y: -5)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text(detail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
                Spacer()
            }
        }
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .foregroundColor(.successGreen)
            Text("授权后我们将读取体重、睡眠与运动记录，全部分析在本机完成。不会写入健康数据，也不会上传网络。")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.successGreen.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                Task { await connect() }
            } label: {
                HStack(spacing: 8) {
                    if isConnecting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "heart.fill")
                    }
                    Text(isConnecting ? "正在连接…" : "连接 Apple 健康")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.brandBlue)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isConnecting)

            Button("稍后手动导入") {
                appState.continueWithMockData()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.textSecondary)
            .disabled(isConnecting)
        }
    }

    @MainActor
    private func connect() async {
        isConnecting = true
        defer { isConnecting = false }
        do {
            try await appState.connectHealthKit()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
