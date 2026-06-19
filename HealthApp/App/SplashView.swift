// SplashView.swift
// 程序启动页：首页数据加载完成前全屏展示品牌图（Assets 中的 LaunchSplash）。
// 由 HealthApp.swift 依据 AppState.isInitialLoadComplete 叠加在内容之上。

import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            // 兜底底色，避免图片在极端比例下露出空白（取图顶部的浅绿白）。
            Color(red: 0.95, green: 0.98, blue: 0.93)
                .ignoresSafeArea()

            Image("LaunchSplash")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack {
                Spacer()
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.brandBlue)
                    .padding(.bottom, 48)
            }
        }
    }
}

#Preview {
    SplashView()
}
