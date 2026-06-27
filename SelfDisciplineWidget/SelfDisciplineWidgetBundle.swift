// SelfDisciplineWidgetBundle.swift
// Widget extension 入口。

import WidgetKit
import SwiftUI

@main
struct SelfDisciplineWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        SelfDisciplineWidget()
        #if DEBUG
        // DEBUG 预览：各状态各注册为一个独立小组件，可分别加到桌面对比。
        SelfDisciplinePreviewWidget(kind: "SDPreviewExercise",  displayName: "DEBUG·运动",     forcedMinutes: 12 * 60)
        SelfDisciplinePreviewWidget(kind: "SDPreviewNoSnack",   displayName: "DEBUG·别吃夜宵", forcedMinutes: 21 * 60)
        SelfDisciplinePreviewWidget(kind: "SDPreviewReadSleep", displayName: "DEBUG·阅读早睡", forcedMinutes: 23 * 60 + 45)
        SelfDisciplinePreviewWidget(kind: "SDPreviewNeutral",   displayName: "DEBUG·非时段",   forcedMinutes: 9 * 60)
        #endif
    }
}
