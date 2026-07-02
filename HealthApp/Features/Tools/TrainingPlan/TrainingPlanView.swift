// TrainingPlanView.swift
// 小工具 · 训练计划：动作库主页。顶部三大类（力量训练 / 拉伸 / HIIT），右上角搜索。

import SwiftUI

struct TrainingPlanView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var profileStore = ProfileStore()
    @State private var mode: TrainingMode = .strength
    @State private var selectedCategory: MuscleCategory = .chest
    @State private var selectedType = Self.allTypes
    @State private var selectedStretchKind = Self.allTypes
    @State private var selectedPart: StretchPart = .chest
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

    var body: some View {
        VStack(spacing: 0) {
            modePicker

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
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
                    scrollToTop(proxy)
                }
                .onChange(of: selectedPart) { _, _ in
                    selectedStretchKind = Self.allTypes
                    scrollToTop(proxy)
                }
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

    // MARK: 力量训练

    private var strengthContent: some View {
        Group {
            categoryTabs
            typeChips
            resultSection
        }
    }

    private var categoryTabs: some View {
        HStack(spacing: 6) {
            ForEach(categories) { category in
                categoryCell(category)
            }
        }
    }

    private func categoryCell(_ category: MuscleCategory) -> some View {
        gridTabCell(category.displayName, selected: category == selectedCategory) {
            guard category != selectedCategory else { return }
            selectedCategory = category
        }
    }

    /// 通用网格 tab 单元：选中橙填充白字，未选 cardBg + hairline 描边（力量肌群 / HIIT 强度共用）。
    private func gridTabCell(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(selected ? .white : .textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(selected ? accent : Color.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.hairline, lineWidth: selected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
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

    private var typeChips: some View {
        underlineChips(categoryTypes, selected: selectedType) { selectedType = $0 }
    }

    /// 通用下划线筛选条（力量类型 / 拉伸类型共用）。
    private func underlineChips(_ items: [String], selected: String,
                                onSelect: @escaping (String) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(items, id: \.self) { item in
                    let isSelected = item == selected
                    Button {
                        guard item != selected else { return }
                        onSelect(item)
                    } label: {
                        Text(item)
                            .font(.system(size: 14, weight: isSelected ? .heavy : .semibold))
                            .foregroundColor(isSelected ? accent : .textSecondary)
                            .frame(height: 36)
                            .overlay(alignment: .bottom) {
                                Capsule()
                                    .fill(isSelected ? accent : Color.clear)
                                    .frame(height: 2)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.hairline).frame(height: 1)
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
        "\(selectedCategory.displayName)部动作"
    }

    // MARK: 拉伸

    private var stretchContent: some View {
        Group {
            stretchBodyMapCard
            stretchKindChips
            stretchResultSection
        }
    }

    private var stretchBodyMapCard: some View {
        bodyMapCard(
            title: "人体部位筛选",
            subtitle: "当前：\(selectedPart.displayName)",
            countText: "\(StretchData.count(in: selectedPart)) 个动作",
            highlighted: stretchHighlightedMuscles
        ) { muscle in
            guard let part = stretchPart(for: muscle) else { return }
            withAnimation(.easeInOut(duration: 0.16)) {
                selectedPart = part
                selectedStretchKind = Self.allTypes
            }
        }
    }

    private var stretchKinds: [String] {
        var seen = Set<String>()
        let kinds = StretchData.moves(in: selectedPart).compactMap { move -> String? in
            seen.insert(move.kind).inserted ? move.kind : nil
        }
        return [Self.allTypes] + kinds
    }

    private var visibleStretchMoves: [StretchMove] {
        let moves = StretchData.moves(in: selectedPart)
        guard selectedStretchKind != Self.allTypes else { return moves }
        return moves.filter { $0.kind == selectedStretchKind }
    }

    // MARK: 拉伸筛选 + 动作列表

    private var stretchKindChips: some View {
        underlineChips(stretchKinds, selected: selectedStretchKind) { selectedStretchKind = $0 }
    }

    private var stretchResultSection: some View {
        let moves = visibleStretchMoves

        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "\(selectedPart.displayName)拉伸") {
                Text("\(moves.count) 个")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textMuted)
            }
            if moves.isEmpty {
                emptyState(text: "该筛选暂无动作")
            } else {
                LazyVStack(spacing: 10) {
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

    private func stretchCard(_ move: StretchMove) -> some View {
        HStack(spacing: 12) {
            stretchThumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(move.name)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
                Text(move.nameEn)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textMuted)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    ExerciseTag(title: move.target, foreground: accent, background: accent.opacity(0.10))
                    ExerciseTag(title: move.kind)
                    DifficultyChip(level: move.difficulty)
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

    private var stretchThumbnail: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(accent.opacity(0.10))
            .frame(width: 104, height: 84)
            .overlay {
                Image(systemName: "figure.flexibility")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(accent)
            }
    }

    // MARK: HIIT

    private var hiitContent: some View {
        Group {
            hiitLevelTabs
            hiitResultSection
        }
    }

    /// 强度网格（3 档单行，镜像力量肌群 tab）。
    private var hiitLevelTabs: some View {
        HStack(spacing: 6) {
            ForEach(HIITLevel.allCases) { level in
                gridTabCell(level.displayName, selected: level == selectedHIITLevel) {
                    guard level != selectedHIITLevel else { return }
                    selectedHIITLevel = level
                }
            }
        }
    }

    private var hiitResultSection: some View {
        let workouts = HIITWorkouts.workouts(in: selectedHIITLevel)

        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "\(selectedHIITLevel.displayName)组合") {
                Text("\(workouts.count) 套")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textMuted)
            }
            if workouts.isEmpty {
                emptyState(text: "该强度暂无组合")
            } else {
                LazyVStack(spacing: 10) {
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

    /// 竖排信息大卡：标题 + 徽章行（强度/时长/循环）+ 难度·强度点阵 + 热量。
    private func hiitCard(_ workout: HIITWorkout) -> some View {
        let kcal = workout.estimatedKcal(weightKg: weightKg)

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(workout.title)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(workout.subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                planBadge(workout.level.displayName, foreground: accent, background: accent.opacity(0.10))
                planBadge("约 \(workout.totalMinutes) 分钟")
                planBadge("\(workout.rounds) 循环")
            }

            HStack(spacing: 6) {
                planMetricBadge(title: "难度", level: hiitDifficulty(workout))
                planMetricBadge(title: "强度", level: hiitIntensity(workout.level))
            }

            if kcal > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("≈ \(formatKcal(kcal)) 千卡 · \(workout.moves.count) 个动作")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(accent)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.hairline, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.035), radius: 8, x: 0, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func hiitDifficulty(_ workout: HIITWorkout) -> Int {
        let moves = workout.moves
        guard !moves.isEmpty else { return 3 }
        let avg = Double(moves.map(\.difficulty).reduce(0, +)) / Double(moves.count)
        return min(max(Int(avg.rounded()), 1), 5)
    }

    private func hiitIntensity(_ level: HIITLevel) -> Int {
        switch level {
        case .beginner:     return 3
        case .intermediate: return 4
        case .advanced:     return 5
        }
    }

    // MARK: 共享组件

    private func bodyMapCard(title: String, subtitle: String, countText: String,
                             highlighted: Set<MuscleGroup>,
                             onTap: @escaping (MuscleGroup) -> Void) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.textPrimary)
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }

                    Spacer(minLength: 8)

                    ExerciseTag(title: countText,
                                foreground: accent,
                                background: accent.opacity(0.10))
                }

                MuscleBodyView(
                    highlighted: highlighted,
                    onTap: onTap,
                    accent: accent,
                    isFemale: isFemale
                )
                .frame(maxWidth: .infinity)
                .frame(height: 300)
            }
        }
    }

    private var stretchHighlightedMuscles: Set<MuscleGroup> {
        Set(stretchMuscles(for: selectedPart))
    }

    private func stretchMuscles(for part: StretchPart) -> [MuscleGroup] {
        switch part {
        case .neck:
            return [.neck]
        case .shoulder:
            return [.frontDeltoids, .deltoids, .rearDeltoids, .trapezius]
        case .chest:
            return [.chest]
        case .back:
            return [.trapezius, .upperBack, .lowerBack]
        case .arm:
            return [.biceps, .triceps, .forearm]
        case .core:
            return [.abs, .obliques]
        case .hip:
            return [.gluteal, .adductor, .abductors]
        case .leg:
            return [.quadriceps, .hamstring, .calves]
        case .fullBody:
            return [.neck, .chest, .frontDeltoids, .upperBack, .abs, .gluteal, .quadriceps, .hamstring, .calves]
        }
    }

    private func stretchPart(for muscle: MuscleGroup) -> StretchPart? {
        switch muscle {
        case .neck:
            return .neck
        case .frontDeltoids, .deltoids, .rearDeltoids:
            return .shoulder
        case .chest:
            return .chest
        case .trapezius, .upperBack, .lowerBack:
            return .back
        case .biceps, .triceps, .forearm:
            return .arm
        case .abs, .obliques:
            return .core
        case .gluteal, .adductor, .abductors:
            return .hip
        case .quadriceps, .hamstring, .calves:
            return .leg
        }
    }

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
