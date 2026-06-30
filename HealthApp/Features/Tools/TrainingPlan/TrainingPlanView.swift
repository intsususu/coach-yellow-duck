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
    @State private var selectedHIITLevel: HIITLevel = .beginner
    @State private var showSearch = false
    @State private var weightKg: Double = 0

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
                    VStack(spacing: 12) {
                        Color.clear.frame(height: 0).id(Self.topAnchor)
                        heroCard

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
                    scrollToTop(proxy)
                }
                .onChange(of: selectedPart) { _, _ in scrollToTop(proxy) }
                .onChange(of: selectedHIITLevel) { _, _ in scrollToTop(proxy) }
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
        HStack(spacing: 6) {
            ForEach(TrainingMode.allCases) { item in
                Button {
                    guard item != mode else { return }
                    mode = item
                } label: {
                    Text(item.displayName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(item == mode ? .textPrimary : .textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(item == mode ? Color.cardBg : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: item == mode ? Color.black.opacity(0.05) : .clear,
                                radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.hairline.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: 顶部摘要

    private var heroCard: some View {
        CardView(padding: 18) {
            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(heroKicker)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(accent)
                    Text(heroTitle)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                    Text(heroSubtitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    ForEach(heroStats, id: \.title) { stat in
                        heroStat(value: stat.value, title: stat.title)
                    }
                }
            }
        }
    }

    private func heroStat(value: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.appBg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var heroKicker: String {
        switch mode {
        case .strength: return "力量训练"
        case .stretch:  return "拉伸"
        case .hiit:     return "HIIT"
        }
    }

    private var heroTitle: String {
        switch mode {
        case .strength: return strengthHeroTitle
        case .stretch:  return "拉伸与活动度"
        case .hiit:     return "HIIT 组合"
        }
    }

    private var heroSubtitle: String {
        switch mode {
        case .strength:
            return "从计划到单动作，按肌群目标快速进入训练。"
        case .stretch:
            return "按部位进入，适合训练前后快速查找。"
        case .hiit:
            return "按强度分层，保留热量估算与循环数，适合快速扫读。"
        }
    }

    private var heroStats: [(value: String, title: String)] {
        switch mode {
        case .strength:
            return [
                ("\(categoryPresets.count)", "训练计划"),
                ("\(TrainingPlanData.exercises(in: selectedCategory).count)", "动作收录"),
                ("\(categoryTypes.count)", "动作类型"),
            ]
        case .stretch:
            return [
                ("\(StretchPart.allCases.count)", "部位"),
                ("\(StretchData.count(in: selectedPart))", "当前动作"),
                ("5", "分钟起"),
            ]
        case .hiit:
            return [
                ("\(HIITLevel.allCases.count)", "强度"),
                ("\(HIITWorkouts.workouts(in: selectedHIITLevel).count)", "当前组合"),
                ("15", "分钟起"),
            ]
        }
    }

    private var strengthHeroTitle: String {
        switch selectedCategory {
        case .core:      return "核心训练"
        case .chest:     return "胸部训练"
        case .back:      return "背部训练"
        case .shoulders: return "肩部训练"
        case .arms:      return "手臂训练"
        case .lower:     return "下肢训练"
        }
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
                        selectedCategory = category
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    private var trainingPlanSection: some View {
        let presets = categoryPresets

        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "训练计划") {
                Text("\(presets.count) 套")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textMuted)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(presets) { preset in
                        NavigationLink {
                            TrainingPlanDetailView(preset: preset)
                        } label: {
                            planCard(preset)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private func planCard(_ preset: TrainingPlanPreset) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(preset.title)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(preset.subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    planBadge(preset.level, foreground: accent, background: accent.opacity(0.10))
                    planBadge("约 \(preset.durationMin) 分钟")
                }
                HStack(spacing: 6) {
                    planMetricBadge(title: "难度", level: presetDifficulty(preset))
                    planMetricBadge(title: "强度", level: presetIntensity(preset))
                }
            }
        }
        .padding(14)
        .frame(width: 244, height: 132, alignment: .leading)
        .background(Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.hairline, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.035), radius: 8, x: 0, y: 2)
    }

    private func planBadge(_ title: String, foreground: Color = .textSecondary, background: Color = .appBg) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(foreground)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(height: 25)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func planMetricBadge(title: String, level: Int) -> some View {
        let value = min(max(level, 0), 5)

        return HStack(spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.textSecondary)
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(index < value ? accent : Color.hairline)
                        .frame(width: 4, height: 4)
                }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 25)
        .background(Color.appBg)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func presetDifficulty(_ preset: TrainingPlanPreset) -> Int {
        if let difficulty = preset.difficultyStars { return difficulty }
        return preset.level == "进阶" ? 3 : 2
    }

    private func presetIntensity(_ preset: TrainingPlanPreset) -> Int {
        if let intensity = preset.intensityStars { return intensity }
        return preset.level == "进阶" ? 4 : 3
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
                        selectedType = type
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
                LazyVStack(spacing: 10) {
                    ForEach(visibleExercises) { exercise in
                        NavigationLink {
                            ExerciseDetailView(exercise: exercise, isFemale: isFemale)
                        } label: {
                            exerciseCard(exercise)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func exerciseCard(_ exercise: Exercise) -> some View {
        HStack(spacing: 12) {
            exerciseThumbnail(exercise: exercise)

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
                Text(exercise.nameEn)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textMuted)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let primary = exercise.primaryMuscles.first {
                        ExerciseTag(title: primary, foreground: accent, background: accent.opacity(0.10))
                    }
                    ExerciseTag(title: exercise.type)
                    DifficultyChip(level: exercise.difficulty)
                }
                .padding(.top, 6)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .background(Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.hairline, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func exerciseThumbnail(exercise: Exercise) -> some View {
        if let illustration = UIImage(named: exercise.image) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accent.opacity(0.08))
                .frame(width: 104, height: 84)
                .overlay {
                    Image(uiImage: illustration)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 104, height: 84)
                        .clipped()
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accent.opacity(0.10))
                .frame(width: 104, height: 84)
                .overlay {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(accent)
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
                                stretchCard(move)
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
                        selectedPart = part
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    private func stretchCard(_ move: StretchMove) -> some View {
        textCard(
            title: move.name,
            subtitle: move.nameEn,
            tags: [move.target, move.kind, DifficultyScale.label(move.difficulty)],
            primaryTagIndex: 0
        )
    }

    // MARK: HIIT

    private var hiitContent: some View {
        Group {
            hiitLevelTabs

            let workouts = HIITWorkouts.workouts(in: selectedHIITLevel)
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "\(selectedHIITLevel.displayName)组合") {
                    Text("\(workouts.count) 套")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textMuted)
                }
                if workouts.isEmpty {
                    emptyState(text: "该强度暂无组合")
                } else {
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

    private var hiitLevelTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HIITLevel.allCases) { level in
                    pill(
                        title: "\(level.displayName) \(HIITWorkouts.workouts(in: level).count)",
                        selected: level == selectedHIITLevel,
                        accent: accent
                    ) {
                        guard level != selectedHIITLevel else { return }
                        selectedHIITLevel = level
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    private func hiitCard(_ workout: HIITWorkout) -> some View {
        let kcal = workout.estimatedKcal(weightKg: weightKg)
        let kcalText = kcal > 0 ? "≈ \(formatKcal(kcal)) 千卡" : nil
        let tags = [kcalText, "\(workout.rounds) 循环", "约 \(workout.totalMinutes) 分钟"]
            .compactMap { $0 }

        return textCard(
            title: workout.title,
            subtitle: workout.subtitle,
            tags: tags,
            primaryTagIndex: kcalText == nil ? nil : 0
        )
    }

    private func textCard(title: String, subtitle: String, tags: [String], primaryTagIndex: Int?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.84)
            Text(subtitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.84)

            HStack(spacing: 6) {
                ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                    ExerciseTag(
                        title: tag,
                        foreground: index == primaryTagIndex ? accent : .textSecondary,
                        background: index == primaryTagIndex ? accent.opacity(0.10) : .appBg
                    )
                }
            }
            .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.hairline, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                .frame(height: 32)
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
                selectedCategory = categories[targetIndex]
            }
    }

    private func scrollToTop(_ proxy: ScrollViewProxy) {
        proxy.scrollTo(Self.topAnchor, anchor: .top)
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
