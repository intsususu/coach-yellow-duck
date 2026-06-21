// AnalysisViews.swift
// 综合分析周期选择与报告页。视觉与 docs/综合分析报告/prototype.html 保持一致。

import SwiftUI
import UIKit

struct AnalysisRangePickerView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: AnalysisViewModel

    @State private var selectedPeriod: AnalysisPeriod? = .week
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var report: AnalysisReport?
    @State private var showsReport = false
    @State private var didApplyInitialRange = false
    @State private var isGenerating = false

    private static let localizedCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh-Hans-CN")
        return calendar
    }()

    init(repository: HealthDataRepository) {
        _viewModel = StateObject(wrappedValue: AnalysisViewModel(repository: repository))
    }

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    periodPicker
                    dateCard
                    statusText
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 96)
            }
            if isGenerating {
                AnalysisLoadingTransitionView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isGenerating)
        .navigationTitle("综合分析")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(isGenerating ? .hidden : .visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            if !isGenerating { generateButton }
        }
        .navigationDestination(isPresented: $showsReport) {
            if let report {
                AnalysisReportView(report: report)
            }
        }
        .task {
            await viewModel.prepare()
            applyInitialRangeIfNeeded()
        }
        .onChange(of: viewModel.latestDataDate) { _, _ in
            applyInitialRangeIfNeeded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("选择分析区间")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.textPrimary)
            Text("选一段时间，小鸭帮你把减脂、运动和睡眠拉到一起复盘。最长支持 3 个月。")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.textSecondary)
                .lineSpacing(4)
        }
    }

    private var periodPicker: some View {
        HStack(spacing: 8) {
            ForEach(AnalysisPeriod.allCases) { period in
                Button {
                    selectedPeriod = period
                    apply(period)
                } label: {
                    Text(period.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(selectedPeriod == period ? .brandBlue : .textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(selectedPeriod == period ? Color.brandBlue.opacity(0.09) : Color.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(selectedPeriod == period ? Color.brandBlue : Color.hairline,
                                        lineWidth: selectedPeriod == period ? 1.5 : 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("起止日期")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.textSecondary)
                .padding(.leading, 4)
            CardView {
                DateRangePickerSection(isPeriod: true,
                                       startDate: $startDate,
                                       endDate: $endDate,
                                       calendar: Self.localizedCalendar)
            }
        }
        .onChange(of: startDate) { _, _ in matchPeriodToDates() }
        .onChange(of: endDate) { _, _ in matchPeriodToDates() }
    }

    @ViewBuilder
    private var statusText: some View {
        if viewModel.isLoading {
            HStack(spacing: 8) {
                ProgressView()
                Text("正在整理本机健康数据…")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.textSecondary)
        } else if let error = viewModel.errorMessage {
            Label(error, systemImage: "exclamationmark.circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.exerciseOrange)
        } else {
            Text(statusMessage)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isRangeValid ? .textMuted : .exerciseOrange)
        }
    }

    private var generateButton: some View {
        Button {
            guard !isGenerating else { return }
            isGenerating = true
            let generatedReport = viewModel.makeReport(startDate: startDate,
                                                       endDate: endDate,
                                                       events: appState.events,
                                                       goalWeight: appState.goalWeight)
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                report = generatedReport
                isGenerating = false
                showsReport = true
            }
        } label: {
            Text("生成报告")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isRangeValid ? Color.brandBlue : Color.brandBlue.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isRangeValid || isGenerating)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var selectedDays: Int {
        max((Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: startDate),
                                             to: Calendar.current.startOfDay(for: endDate)).day ?? 0) + 1, 0)
    }

    private var isRangeValid: Bool {
        !viewModel.isLoading
        && viewModel.errorMessage == nil
        && selectedDays > 0
        && selectedDays <= 92
        && viewModel.dataDayCount(from: startDate, to: endDate) > 0
    }

    private var statusMessage: String {
        if selectedDays > 92 {
            return "已选 \(selectedDays) 天 · 超过 3 个月上限，请缩短区间"
        }
        let count = viewModel.dataDayCount(from: startDate, to: endDate)
        return "已选 \(selectedDays) 天 · 区间内有数据 \(count) 天"
    }

    private func applyInitialRangeIfNeeded() {
        guard !didApplyInitialRange, let latest = viewModel.latestDataDate else { return }
        didApplyInitialRange = true
        endDate = Calendar.current.startOfDay(for: latest)
        apply(.week)
    }

    private func apply(_ period: AnalysisPeriod) {
        startDate = Calendar.current.date(byAdding: .day,
                                         value: -(period.rawValue - 1),
                                         to: Calendar.current.startOfDay(for: endDate)) ?? endDate
    }

    private func matchPeriodToDates() {
        selectedPeriod = AnalysisPeriod.allCases.first { $0.rawValue == selectedDays }
    }
}

private struct AnalysisLoadingTransitionView: View {
    var body: some View {
        ZStack {
            Color.appBg
                .ignoresSafeArea()
            VStack(spacing: 18) {
                Image("ChickAvatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 86, height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color.eventTravel.opacity(0.18), radius: 12, y: 5)
                Text("小鸭教练分析中")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.textPrimary)
                ProgressView()
                    .tint(.brandBlue)
                    .scaleEffect(1.15)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("小鸭教练分析中")
        }
    }
}

struct AnalysisReportView: View {
    let report: AnalysisReport
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale

    @State private var shareItem: ShareImageItem?

    var body: some View {
        ZStack {
            shareBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    topBar
                    reportBody
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
        }
        // 沉浸式：隐藏系统导航栏，渐变直达顶部，返回用自定义按钮。
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        // 隐藏导航栏后，确保左缘右滑返回手势仍然可用。
        .background(SwipeBackGestureEnabler())
        .sheet(item: $shareItem) { item in
            SharePreviewView(image: item.image)
        }
    }

    /// 可分享的报告主体（不含顶部返回/分享栏），既用于页面展示也用于长截图渲染。
    private var reportBody: some View {
        VStack(spacing: 14) {
            shareHeader
            overviewCard
            insightCard(title: "给你点赞", systemImage: "hand.thumbsup.fill",
                        color: .successGreen, items: report.positives)
            insightCard(title: "需要关注", systemImage: "exclamationmark.triangle.fill",
                        color: .warningAmber, items: report.warnings)
            messageCard
            shareFooter
        }
    }

    /// 顶部栏：左侧自定义返回（隐藏导航栏后替代系统返回；左缘右滑仍可用），右侧分享。
    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            Spacer()
            Button { generateShareImage() } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("分享报告")
        }
    }

    /// 把整份报告（含顶部渐变）渲染成一张长图，用于分享 / 保存。
    @MainActor
    private func generateShareImage() {
        let width = UIScreen.main.bounds.width
        let content = reportBody
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 24)
            .frame(width: width)
            .background(shareBackground)
        let renderer = ImageRenderer(content: content)
        renderer.scale = displayScale
        guard let image = renderer.uiImage else { return }
        shareItem = ShareImageItem(image: image)
    }

    // MARK: - 分享封面：品牌头部 + 渐变背景 + 底部水印

    /// 暖米色到中性底色的柔和渐变，呼应「小黄鸡」品牌、让白卡片更跳。
    private var shareBackground: some View {
        LinearGradient(colors: [Color.eventTravelBg, Color.appBg],
                       startPoint: .top, endPoint: .bottom)
    }

    private var shareHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image("ChickAvatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .shadow(color: Color.eventTravel.opacity(0.22), radius: 7, y: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("加油吖！")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.eventTravel)
                    Text("本期复盘")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.textPrimary)
                }
                Spacer(minLength: 8)
                sentimentBadge
            }
            Text("\(Self.rangeFormatter.string(from: report.startDate)) – \(Self.rangeFormatter.string(from: report.endDate)) · 较上一周期")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.textSecondary)
        }
        .padding(.vertical, 2)
    }

    private var sentimentBadge: some View {
        let style = sentimentStyle
        return Text(style.label)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(style.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(style.color.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(style.color.opacity(0.25), lineWidth: 1))
    }

    private var shareFooter: some View {
        HStack(spacing: 6) {
            Image("ChickAvatar")
                .resizable()
                .scaledToFill()
                .frame(width: 16, height: 16)
                .clipShape(Circle())
            Text("由 加油吖！生成 · 记录每一天的自律")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }

    private var sentimentStyle: (label: String, color: Color) {
        switch report.sentiment {
        case .positive: return ("状态向好", .successGreen)
        case .negative: return ("需要加油", .warningAmber)
        case .neutral:  return ("稳步保持", .brandBlue)
        }
    }

    private static let rangeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()

    private var overviewCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.brandBlue)
                    Text("小鸭教练说")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.textPrimary)
                }

                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.brandBlue.opacity(0.45))
                        .frame(width: 3)
                    Text(report.narrative)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(Color.brandBlue.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                summaryBlock(title: "体重",
                             systemImage: "figure",
                             color: .weightGreen,
                             background: .weightCardBg) {
                    HStack(spacing: 8) {
                        summaryMetric(title: "周期内体重变化",
                                      value: report.weightSummary.change,
                                      color: .weightGreen)
                        summaryMetric(title: "距离体重目标",
                                      value: report.weightSummary.distanceToGoal,
                                      color: .weightGreen)
                    }
                }

                summaryBlock(title: "运动",
                             systemImage: "figure.run",
                             color: .exerciseOrange,
                             background: .exerciseCardBg) {
                    HStack(spacing: 7) {
                        summaryMetric(title: "运动总消耗",
                                      value: report.exerciseSummary.totalKcal,
                                      color: .exerciseOrange)
                        summaryMetric(title: "运动总次数",
                                      value: report.exerciseSummary.totalCount,
                                      color: .exerciseOrange)
                        summaryMetric(title: "运动总时间",
                                      value: report.exerciseSummary.totalTime,
                                      color: .exerciseOrange)
                    }
                    summaryDetailRow(systemImage: "flame.fill",
                                     title: "消耗最大单日 · \(report.exerciseSummary.peakDay)",
                                     value: report.exerciseSummary.peakDayKcal,
                                     detail: report.exerciseSummary.peakDayBreakdown,
                                     color: .exerciseOrange)
                    summaryDetailRow(systemImage: "trophy.fill",
                                     title: "最常运动类型",
                                     value: report.exerciseSummary.dominantType,
                                     detail: "累计运动 \(report.exerciseSummary.dominantTypeTime)",
                                     color: .exerciseOrange)
                }

                summaryBlock(title: "睡眠",
                             systemImage: "moon.fill",
                             color: .sleepIndigo,
                             background: .sleepCardBg) {
                    HStack(spacing: 7) {
                        summaryMetric(title: "日均质量评分",
                                      value: report.sleepSummary.averageScore,
                                      color: .sleepIndigo)
                        summaryMetric(title: "最高分",
                                      value: report.sleepSummary.highestScore,
                                      color: .sleepIndigo)
                        summaryMetric(title: "最低分",
                                      value: report.sleepSummary.lowestScore,
                                      color: .sleepIndigo)
                    }
                    HStack(spacing: 7) {
                        summaryMetric(title: "日均睡眠时长",
                                      value: report.sleepSummary.averageDuration,
                                      color: .sleepIndigo)
                        summaryMetric(title: "日均就寝时间",
                                      value: report.sleepSummary.averageBedtime,
                                      color: .sleepIndigo)
                        summaryMetric(title: "日均起床时间",
                                      value: report.sleepSummary.averageWakeTime,
                                      color: .sleepIndigo)
                    }
                }
            }
        }
    }

    private func summaryBlock<Content: View>(title: String,
                                             systemImage: String,
                                             color: Color,
                                             background: Color,
                                             @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func summaryMetric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
        .background(Color.cardBg.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func summaryDetailRow(systemImage: String,
                                  title: String,
                                  value: String,
                                  detail: String,
                                  color: Color) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textSecondary)
                    Spacer()
                    Text(value)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(color)
                }
                Text(detail)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.textMuted)
                    .lineSpacing(2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
        .background(Color.cardBg.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func insightCard(title: String,
                             systemImage: String,
                             color: Color,
                             items: [AnalysisInsight]) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(title, systemImage: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                    Spacer()
                    if !items.isEmpty {
                        Text("\(items.count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(color)
                            .padding(.horizontal, 8)
                            .frame(minHeight: 20)
                            .background(color.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                if items.isEmpty {
                    Text("这个周期没有明显风险，继续保持当前节奏。")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.textSecondary)
                } else {
                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: item.systemImage)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(item.tone == .positive ? .successGreen : .warningAmber)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.textPrimary)
                                Text(item.detail)
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(.textMuted)
                                    .lineSpacing(3)
                            }
                        }
                    }
                }
            }
        }
    }

    private var messageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 图标与标题尺寸对齐上方「小鸭教练说」头部。
            HStack(spacing: 9) {
                Image("ChickAvatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color.eventTravel.opacity(0.16), radius: 4, y: 2)
                Text("小鸭教练还想说")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.eventTravel)
            }
            Text(report.messages.first ?? "")
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundColor(.textPrimary)
                .lineSpacing(7)
                .frame(maxWidth: .infinity, alignment: .topLeading)

            // 底部签名：一条连续实线 + 报告生成时间，靠右。
            HStack(spacing: 8) {
                Spacer()
                Rectangle()
                    .fill(Color.textMuted.opacity(0.55))
                    .frame(width: 32, height: 1)
                Text(Self.signatureFormatter.string(from: report.generatedAt))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.textMuted)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.eventTravelBg)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.eventTravel.opacity(0.18), lineWidth: 1)
        )
    }

    private static let signatureFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

}

/// 隐藏系统导航栏后，SwiftUI 可能连带禁用左缘右滑返回手势。
/// 通过接管 interactivePopGestureRecognizer 的代理，在栈内有可返回页面时放行手势。
private struct SwipeBackGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { GestureController() }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class GestureController: UIViewController, UIGestureRecognizerDelegate {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            if let gesture = navigationController?.interactivePopGestureRecognizer {
                gesture.delegate = self
                gesture.isEnabled = true
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }
}

// MARK: - 分享预览：长截图 + 保存到相册 + 系统分享

private struct SharePreviewView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var showSystemShare = false
    @State private var savedToast = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) { actionBar }
        .overlay(alignment: .top) {
            if savedToast {
                Label("已保存到相册", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.8))
                    .clipShape(Capsule())
                    .padding(.top, 76)
                    .transition(.opacity)
            }
        }
        // 半屏多一点的液态玻璃面板；点击窗口外 / 下滑可关闭。
        .presentationDetents([.fraction(0.56)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(.ultraThinMaterial)
        .sheet(isPresented: $showSystemShare) {
            ShareSheet(items: [image])
        }
    }

    private var header: some View {
        HStack {
            Text("分享预览")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.textPrimary)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.textSecondary)
                    .frame(width: 30, height: 30)
                    .liquidGlassCircle()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭")
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    /// 底部玻璃操作条：钉在面板底部，避免下方留白。
    private var actionBar: some View {
        HStack(spacing: 0) {
            actionItem(icon: "square.and.arrow.down", label: "保存", tint: .brandBlue) {
                saveToAlbum()
            }
            actionItem(icon: "square.and.arrow.up", label: "系统分享", tint: .brandBlue) {
                showSystemShare = true
            }
            actionItem(icon: "hammer.fill", label: "建设中", tint: .textMuted, enabled: false) {}
        }
        .padding(.top, 14)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.3)).frame(height: 1)
        }
    }

    private func actionItem(icon: String,
                            label: String,
                            tint: Color,
                            enabled: Bool = true,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(enabled ? tint : .textMuted)
                    .frame(width: 56, height: 56)
                    .liquidGlassCircle()
                    .opacity(enabled ? 1 : 0.55)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(enabled ? .textSecondary : .textMuted)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func saveToAlbum() {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        withAnimation { savedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { savedToast = false }
        }
    }
}

private extension View {
    /// 圆形液态玻璃背景：iOS 26 用系统 Liquid Glass，更低版本回退到毛玻璃材质。
    @ViewBuilder
    func liquidGlassCircle() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: Circle())
        } else {
            self.background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
        }
    }
}

/// 用 Identifiable 包裹长图，配合 fullScreenCover(item:) 避免可选状态时序坑。
private struct ShareImageItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
