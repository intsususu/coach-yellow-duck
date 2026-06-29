// TrainingPlanView.swift
// 小工具 · 训练计划：动作库主页。顶部三大类（力量训练 / 拉伸 / HIIT），右上角搜索。

import SwiftUI

struct TrainingPlanView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var profileStore = ProfileStore()
    @State private var mode: TrainingMode = .strength
    @State private var selectedCategory: MuscleCategory = .chest
    @State private var selectedType = Self.allTypes
    @State private var selectedPart: StretchPart = .neck
    @State private var showSearch = false
    @State private var weightKg: Double = 0
    @State private var presetsExpanded = false

    private static let collapsedPresetCount = 2

    private static let allTypes = "全部"
    private static let topAnchor = "trainingPlanTop"

    private let categories: [MuscleCategory] = [.chest, .shoulders, .back, .lower, .core, .arms]

    private var isFemale: Bool {
        profileStore.profile.gender == .female
    }

    private var accent: Color { .exerciseOrange }

    // MARK: 力量筛选

    private var visibleExercises: [Exercise] {
        let exercises = TrainingPlanData.exercises(in: selectedCategory)
        guard selectedType != Self.allTypes else { return exercises }
        return exercises.filter { $0.type == selectedType }
    }

    private var categoryTypes: [String] {
        [Self.allTypes] + TrainingPlanData.types(in: selectedCategory)
    }

    private var categoryPresets: [TrainingPlanPreset] {
        TrainingPlanPresets.presets(in: selectedCategory)
    }

    var body: some View {
        VStack(spacing: 0) {
            modePicker

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        Color.clear.frame(height: 0).id(Self.topAnchor)

                        switch mode {
                        case .strength: strengthContent
                        case .stretch:  stretchContent
                        case .hiit:     hiitContent
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 18)
                }
                .gesture(pageSwipeGesture)
                .onChange(of: mode) { _, _ in scrollToTop(proxy) }
                .onChange(of: selectedCategory) { _, _ in
                    selectedType = Self.allTypes
                    presetsExpanded = false
                    scrollToTop(proxy)
                }
                .onChange(of: selectedType) { _, _ in scrollToTop(proxy) }
                .onChange(of: selectedPart) { _, _ in scrollToTop(proxy) }
            }

            disclaimer
        }
        .environment(\.bodyWeightKg, weightKg)
        .background(Color.appBg.ignoresSafeArea())
        .navigationTitle("训练计划")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .sheet(isPresented: $showSearch) {
            TrainingSearchView()
                .environment(\.bodyWeightKg, weightKg)
        }
        .task {
            guard weightKg == 0 else { return }
            let latest = await appState.repository.weightStatistics().current
            weightKg = latest ?? BodyWeight.estimate(heightCm: profileStore.profile.heightCm)
        }
    }

    // MARK: 顶部三大类

    private var modePicker: some View {
        HStack(spacing: 8) {
            ForEach(TrainingMode.allCases) { item in
                Button {
                    guard item != mode else { return }
                    withAnimation(.easeInOut(duration: 0.18)) { mode = item }
                } label: {
                    Text(item.displayName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(item == mode ? .white : .textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(item == mode ? accent : Color.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(Color.hairline, lineWidth: item == mode ? 0 : 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: 力量训练

    private var strengthContent: some View {
        Group {
            categoryTabs

            if !categoryPresets.isEmpty {
                trainingPlanSection
            }

            typeChips
            resultSection
        }
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories) { category in
                    pill(
                        title: "\(category.displayName) \(TrainingPlanData.exercises(in: category).count)",
                        selected: category == selectedCategory,
                        accent: accent
                    ) {
                        guard category != selectedCategory else { return }
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    private var trainingPlanSection: some View {
        let presets = categoryPresets
        let canExpand = presets.count > Self.collapsedPresetCount
        let shown = (presetsExpanded || !canExpand)
            ? presets
            : Array(presets.prefix(Self.collapsedPresetCount))

        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "训练计划") {
                if canExpand {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { presetsExpanded.toggle() }
                    } label: {
                        HStack(spacing: 3) {
                            Text("\(presets.count) 套")
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .rotationEffect(.degrees(presetsExpanded ? 90 : 0))
                        }
                        .foregroundColor(accent)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("\(presets.count) 套")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textMuted)
                }
            }
            VStack(spacing: 8) {
                ForEach(shown) { preset in
                    NavigationLink {
                        TrainingPlanDetailView(preset: preset)
                    } label: {
                        planCard(preset)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func planCard(_ preset: TrainingPlanPreset) -> some View {
        let levelColor = Self.levelColor(preset.level)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(preset.level)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(levelColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(levelColor.opacity(0.14)))
                    Text(preset.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                }
                Text(preset.subtitle)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    ExerciseTag(title: "\(preset.exercises.count) 动作")
                    ExerciseTag(title: "约 \(preset.durationMin) 分钟")
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textMuted.opacity(0.7))
        }
        .padding(13)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.cardBg))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.hairline, lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(levelColor)
                .frame(width: 3.5)
                .padding(.vertical, 12)
        }
    }

    /// 难度档颜色：入门绿、进阶橙。
    private static func levelColor(_ level: String) -> Color {
        switch level {
        case "入门": return .successGreen
        case "进阶": return .exerciseOrange
        default:    return .brandBlue
        }
    }

    private var typeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categoryTypes, id: \.self) { type in
                    pill(
                        title: type,
                        selected: type == selectedType,
                        accent: accent
                    ) {
                        guard type != selectedType else { return }
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedType = type
                        }
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: strengthResultTitle) {
                Text("\(visibleExercises.count) 个")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textMuted)
            }

            if visibleExercises.isEmpty {
                emptyState(text: "该筛选暂无动作")
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(visibleExercises) { exercise in
                        NavigationLink {
                            ExerciseDetailView(exercise: exercise, isFemale: isFemale)
                        } label: {
                            ExerciseRow(exercise: exercise, accent: accent, isFemale: isFemale)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var strengthResultTitle: String {
        if selectedType == Self.allTypes { return "\(selectedCategory.displayName)部动作" }
        return selectedType
    }

    // MARK: 拉伸

    private var stretchContent: some View {
        Group {
            partTabs

            let moves = StretchData.moves(in: selectedPart)
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "\(selectedPart.displayName)拉伸") {
                    Text("\(moves.count) 个")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textMuted)
                }
                if moves.isEmpty {
                    emptyState(text: "该部位暂无动作")
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(moves) { move in
                            NavigationLink {
                                MoveDetailView(stretch: move)
                            } label: {
                                ExerciseRow(stretch: move, accent: accent, isFemale: isFemale)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var partTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StretchPart.allCases) { part in
                    pill(
                        title: "\(part.displayName) \(StretchData.count(in: part))",
                        selected: part == selectedPart,
                        accent: accent
                    ) {
                        guard part != selectedPart else { return }
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedPart = part
                        }
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    // MARK: HIIT

    private var hiitContent: some View {
        ForEach(HIITLevel.allCases) { level in
            let workouts = HIITWorkouts.workouts(in: level)
            if !workouts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(title: "\(level.displayName)组合") {
                        Text(level.subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.textMuted)
                    }
                    VStack(spacing: 8) {
                        ForEach(workouts) { workout in
                            NavigationLink {
                                HIITWorkoutDetailView(workout: workout)
                            } label: {
                                hiitCard(workout)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func hiitCard(_ workout: HIITWorkout) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accent.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: "flame.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                Text(workout.subtitle)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    let kcal = workout.estimatedKcal(weightKg: weightKg)
                    if kcal > 0 {
                        ExerciseTag(title: "≈ \(formatKcal(kcal)) 千卡", foreground: accent, background: accent.opacity(0.10))
                    }
                    ExerciseTag(title: "\(workout.rounds) 循环")
                    ExerciseTag(title: "约 \(workout.totalMinutes) 分钟")
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textMuted.opacity(0.7))
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.hairline, lineWidth: 1))
    }

    // MARK: 共享组件

    private func emptyState(text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.textMuted)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.hairline, lineWidth: 1)
        )
    }

    private func pill(title: String, selected: Bool, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(selected ? .white : .textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(selected ? accent : Color.cardBg)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.hairline, lineWidth: selected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var disclaimer: some View {
        Text("训练动作仅供参考，请量力而行，必要时在专业指导下进行")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.textMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.cardBg)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.hairline).frame(height: 1)
            }
    }

    // MARK: 手势：力量左右切肌群

    private var pageSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 32, coordinateSpace: .local)
            .onEnded { value in
                guard mode == .strength else { return }
                let horizontal = value.translation.width
                let vertical = abs(value.translation.height)
                guard abs(horizontal) > 48, abs(horizontal) > vertical else { return }
                guard let index = categories.firstIndex(of: selectedCategory) else { return }
                let targetIndex = horizontal < 0 ? index + 1 : index - 1
                guard categories.indices.contains(targetIndex) else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    selectedCategory = categories[targetIndex]
                }
            }
    }

    private func scrollToTop(_ proxy: ScrollViewProxy) {
        withAnimation(.easeInOut(duration: 0.18)) {
            proxy.scrollTo(Self.topAnchor, anchor: .top)
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        TrainingPlanView()
    }
    .environmentObject(AppState(repository: MockHealthRepository()))
}
#endif
