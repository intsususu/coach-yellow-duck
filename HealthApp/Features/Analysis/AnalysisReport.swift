// AnalysisReport.swift
// 综合分析的数据模型与纯计算引擎。所有结果均由仓库样本按所选区间计算。

import Foundation

enum AnalysisPeriod: Int, CaseIterable, Identifiable {
    case week = 7
    case month = 30
    case threeMonths = 90

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .week: return "近一周"
        case .month: return "近一个月"
        case .threeMonths: return "近三个月"
        }
    }
}

enum AnalysisSentiment {
    case positive, negative, neutral
}

enum AnalysisInsightTone {
    case positive, warning
}

struct AnalysisInsight: Identifiable {
    let id = UUID()
    let systemImage: String
    let title: String
    let detail: String
    let tone: AnalysisInsightTone
}

struct AnalysisWeightSummary {
    let change: String
    let distanceToGoal: String
}

struct AnalysisExerciseSummary {
    let totalKcal: String
    let totalCount: String
    let totalTime: String
    let peakDay: String
    let peakDayKcal: String
    let peakDayBreakdown: String
    let dominantType: String
    let dominantTypeTime: String
}

struct AnalysisSleepSummary {
    let averageScore: String
    let highestScore: String
    let lowestScore: String
    let averageDuration: String
    let averageBedtime: String
    let averageWakeTime: String
}

struct AnalysisReport {
    let startDate: Date
    let endDate: Date
    /// 报告生成时刻，用于「小鸭教练还想说」卡片底部签名。
    let generatedAt: Date
    let selectedDays: Int
    let dataDays: Int
    let weightSummary: AnalysisWeightSummary
    let exerciseSummary: AnalysisExerciseSummary
    let sleepSummary: AnalysisSleepSummary
    let positives: [AnalysisInsight]
    let warnings: [AnalysisInsight]
    let sentiment: AnalysisSentiment
    /// 一句话「加工语句」：把体重 / 运动 / 睡眠三条信号合成的自然语言小结。
    /// 同时用于综合分析报告「小鸭教练说」下方与首页「本周小结」。
    let narrative: String
    let messages: [String]
}

struct AnalysisReportEngine {
    private let calendar: Calendar

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func makeReport(weights: [WeightSample],
                    sleeps: [SleepSample],
                    workouts: [WorkoutSession],
                    events: [HealthEvent],
                    goalWeight: Double,
                    startDate: Date,
                    endDate: Date) -> AnalysisReport {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        let selectedDays = max((calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1, 1)
        let currentEnd = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        let previousStart = calendar.date(byAdding: .day, value: -selectedDays, to: start) ?? start

        let currentWeights = weights.inWindow(start: start, end: currentEnd, date: \WeightSample.date)
        let previousWeights = weights.inWindow(start: previousStart, end: start, date: \WeightSample.date)
        let currentSleeps = sleeps.inWindow(start: start, end: currentEnd, date: \SleepSample.date)
        let previousSleeps = sleeps.inWindow(start: previousStart, end: start, date: \SleepSample.date)
        let currentWorkouts = workouts.inWindow(start: start, end: currentEnd, date: \WorkoutSession.start)
        let previousWorkouts = workouts.inWindow(start: previousStart, end: start, date: \WorkoutSession.start)
        let currentEvents = events.filter { event in
            let eventEnd = event.endDate ?? event.startDate
            return event.startDate < currentEnd && eventEnd >= start
        }

        let weightChange = change(in: currentWeights)
        let previousWeightChange = change(in: previousWeights)
        let frequency = Double(currentWorkouts.count) / Double(selectedDays) * 7
        let previousFrequency = Double(previousWorkouts.count) / Double(selectedDays) * 7
        let averageSleep = average(currentSleeps.map(\.totalHours))
        let previousAverageSleep = average(previousSleeps.map(\.totalHours))
        let qualityScores = SleepQualityCalculator.scores(for: sleeps)
            .inWindow(start: start, end: currentEnd, date: \SleepQualityScore.date)

        let dataDays = Set(
            currentWeights.map { calendar.startOfDay(for: $0.date) }
            + currentSleeps.map { calendar.startOfDay(for: $0.date) }
            + currentWorkouts.map { calendar.startOfDay(for: $0.start) }
        ).count

        var positives = positiveInsights(weightChange: weightChange,
                                         previousWeightChange: previousWeightChange,
                                         frequency: frequency,
                                         previousFrequency: previousFrequency,
                                         averageSleep: averageSleep,
                                         previousAverageSleep: previousAverageSleep,
                                         currentSleeps: currentSleeps,
                                         previousSleeps: previousSleeps,
                                         currentWorkouts: currentWorkouts,
                                         qualityScores: qualityScores,
                                         currentEvents: currentEvents,
                                         previousEvents: events.filter {
                                             let eventEnd = $0.endDate ?? $0.startDate
                                             return $0.startDate < start && eventEnd >= previousStart
                                         },
                                         dataDays: dataDays,
                                         selectedDays: selectedDays)
        var warnings = warningInsights(weightChange: weightChange,
                                       frequency: frequency,
                                       previousFrequency: previousFrequency,
                                       averageSleep: averageSleep,
                                       currentSleeps: currentSleeps,
                                       currentWorkouts: currentWorkouts,
                                       currentEvents: currentEvents,
                                       dataDays: dataDays,
                                       selectedDays: selectedDays)

        if positives.isEmpty {
            positives.append(AnalysisInsight(systemImage: "checkmark.circle.fill",
                                             title: "保持得不错",
                                             detail: "这段时间仍有持续记录，愿意回看数据本身就是稳定习惯的一部分。",
                                             tone: .positive))
        }
        positives = Array(positives.prefix(4))
        warnings = Array(warnings.prefix(4))

        let sentiment: AnalysisSentiment
        if (weightChange ?? 0) < -0.2 && positives.count >= warnings.count {
            sentiment = .positive
        } else if (weightChange ?? 0) > 0.2 || warnings.count >= positives.count + 2 {
            sentiment = .negative
        } else {
            sentiment = .neutral
        }

        return AnalysisReport(startDate: start,
                              endDate: end,
                              generatedAt: Date(),
                              selectedDays: selectedDays,
                              dataDays: dataDays,
                              weightSummary: makeWeightSummary(samples: currentWeights,
                                                               change: weightChange,
                                                               goalWeight: goalWeight),
                              exerciseSummary: makeExerciseSummary(workouts: currentWorkouts),
                              sleepSummary: makeSleepSummary(samples: currentSleeps,
                                                             scores: qualityScores),
                              positives: positives,
                              warnings: warnings,
                              sentiment: sentiment,
                              narrative: narrativeSummary(weightChange: weightChange,
                                                          previousWeightChange: previousWeightChange,
                                                          frequency: frequency,
                                                          previousFrequency: previousFrequency,
                                                          averageSleep: averageSleep,
                                                          previousAverageSleep: previousAverageSleep,
                                                          currentEvents: currentEvents,
                                                          sentiment: sentiment),
                              // 打乱后取首条，让每次生成的鸡汤文案有变化。
                              messages: messages(for: sentiment).shuffled())
    }

    /// 把体重、运动、睡眠三条趋势信号合成一句自然语言小结。
    /// 体重为主句，运动 + 睡眠合成次句，运动相关事件追加为补充说明，
    /// 句尾按整体情绪附一个表情。逻辑与 positives/warnings 的判定阈值保持一致。
    private func narrativeSummary(weightChange: Double?,
                                  previousWeightChange: Double?,
                                  frequency: Double,
                                  previousFrequency: Double,
                                  averageSleep: Double?,
                                  previousAverageSleep: Double?,
                                  currentEvents: [HealthEvent],
                                  sentiment: AnalysisSentiment) -> String {
        var clauses: [String] = []

        // 体重主句。
        if let weightChange {
            if weightChange < -0.2 {
                if let previousWeightChange, previousWeightChange < -0.2 {
                    clauses.append("体重连续两个周期下降，本期再减 \(String(format: "%.1f", abs(weightChange)))kg")
                } else {
                    clauses.append("体重下降 \(String(format: "%.1f", abs(weightChange)))kg")
                }
            } else if weightChange > 0.2 {
                clauses.append("体重回升 \(String(format: "%.1f", weightChange))kg")
            } else {
                clauses.append("体重基本持平")
            }
        }

        // 运动 + 睡眠合成次句。
        let exerciseUp = frequency > previousFrequency + 0.25
        let exerciseDown = previousFrequency > 0.5 && frequency < previousFrequency * 0.75
        let sleepUp: Bool = {
            guard let averageSleep, let previousAverageSleep else { return false }
            return averageSleep > previousAverageSleep + 0.15
        }()
        let sleepShort = (averageSleep ?? 8) < 7

        switch (exerciseUp, sleepUp) {
        case (true, true):
            clauses.append("运动负荷与睡眠时长同步走高")
        case (true, false):
            clauses.append("运动量比上一周期明显增加")
        case (false, true):
            clauses.append("睡眠时长比上一周期更充足")
        case (false, false):
            if exerciseDown && sleepShort {
                clauses.append("运动和睡眠都有些松动")
            } else if exerciseDown {
                clauses.append("运动节奏略有放缓")
            } else if sleepShort {
                clauses.append("睡眠时长偏少、记得多留点恢复时间")
            }
        }

        var sentence = clauses.joined(separator: "，")
        if sentence.isEmpty {
            sentence = "本周期记录还不多，先把每天的数据坚持下来"
        }

        // 运动相关事件（如出差、感冒）可能解释同期波动，作为补充句。
        if let event = currentEvents.first(where: { $0.type.isExerciseRelated }) {
            sentence += "；其间「\(event.title)」覆盖 \(eventDuration(event)) 天，可能是同期波动的原因"
        }

        switch sentiment {
        case .positive: sentence += " 👍"
        case .negative: sentence += " 💪"
        case .neutral: break
        }
        return sentence
    }

    private func makeWeightSummary(samples: [WeightSample],
                                   change: Double?,
                                   goalWeight: Double) -> AnalysisWeightSummary {
        let latest = samples.max { $0.date < $1.date }?.kg
        let changeText = change.map { signed($0, suffix: "kg") } ?? "--"
        let distanceText: String
        if let latest {
            let distance = (latest - goalWeight).rounded(toPlaces: 1)
            distanceText = distance > 0
                ? "还差 \(String(format: "%.1f", distance))kg"
                : "已达成 \(String(format: "%.1f", abs(distance)))kg"
        } else {
            distanceText = "--"
        }
        return AnalysisWeightSummary(change: changeText, distanceToGoal: distanceText)
    }

    private func makeExerciseSummary(workouts: [WorkoutSession]) -> AnalysisExerciseSummary {
        guard !workouts.isEmpty else {
            return AnalysisExerciseSummary(totalKcal: "--", totalCount: "0次", totalTime: "--",
                                           peakDay: "--", peakDayKcal: "--", peakDayBreakdown: "暂无运动记录",
                                           dominantType: "--", dominantTypeTime: "--")
        }

        let totalKcal = workouts.reduce(0) { $0 + $1.kcal }
        let totalMinutes = workouts.reduce(0) { $0 + $1.minutes }
        let byDay = Dictionary(grouping: workouts) { calendar.startOfDay(for: $0.start) }
        let peak = byDay.max { lhs, rhs in
            lhs.value.reduce(0) { $0 + $1.kcal } < rhs.value.reduce(0) { $0 + $1.kcal }
        }
        let peakWorkouts = peak?.value ?? []
        let peakTotal = peakWorkouts.reduce(0) { $0 + $1.kcal }
        let peakTypes = Dictionary(grouping: peakWorkouts, by: \.type)
            .map { kind, entries in
                (kind, entries.reduce(0) { $0 + $1.kcal })
            }
            .sorted { $0.1 > $1.1 }
        let breakdown = peakTypes.map { "\($0.0.label) \(formatKcal($0.1))" }.joined(separator: " · ")

        let byType = Dictionary(grouping: workouts, by: \.type)
        let dominant = byType.max { lhs, rhs in
            if lhs.value.count == rhs.value.count {
                return lhs.value.reduce(0) { $0 + $1.minutes } < rhs.value.reduce(0) { $0 + $1.minutes }
            }
            return lhs.value.count < rhs.value.count
        }
        let dominantMinutes = dominant?.value.reduce(0) { $0 + $1.minutes } ?? 0
        let dominantLabel = dominant.map { "\($0.key.label) · \($0.value.count)次" } ?? "--"

        return AnalysisExerciseSummary(totalKcal: formatKcal(totalKcal),
                                       totalCount: "\(workouts.count)次",
                                       totalTime: formatMinutes(totalMinutes),
                                       peakDay: peak.map { Self.shortDateFormatter.string(from: $0.key) } ?? "--",
                                       peakDayKcal: formatKcal(peakTotal),
                                       peakDayBreakdown: breakdown.isEmpty ? "暂无运动记录" : breakdown,
                                       dominantType: dominantLabel,
                                       dominantTypeTime: formatMinutes(dominantMinutes))
    }

    private func makeSleepSummary(samples: [SleepSample],
                                  scores: [SleepQualityScore]) -> AnalysisSleepSummary {
        let scoreValues = scores.map(\.score)
        let averageScore = average(scoreValues).map { "\(Int($0.rounded()))分" } ?? "--"
        let highestScore = scoreValues.max().map { "\(Int($0.rounded()))分" } ?? "--"
        let lowestScore = scoreValues.min().map { "\(Int($0.rounded()))分" } ?? "--"
        let averageDuration = average(samples.map(\.totalHours))
            .map { String(format: "%.1f小时", $0) } ?? "--"
        let bedtime = formatClock(averageClockMinutes(samples.compactMap(\.bedtime), noonAnchored: true))
        let wakeTime = formatClock(averageClockMinutes(samples.compactMap(\.wakeTime), noonAnchored: false))
        return AnalysisSleepSummary(averageScore: averageScore,
                                    highestScore: highestScore,
                                    lowestScore: lowestScore,
                                    averageDuration: averageDuration,
                                    averageBedtime: bedtime,
                                    averageWakeTime: wakeTime)
    }

    private func positiveInsights(weightChange: Double?,
                                  previousWeightChange: Double?,
                                  frequency: Double,
                                  previousFrequency: Double,
                                  averageSleep: Double?,
                                  previousAverageSleep: Double?,
                                  currentSleeps: [SleepSample],
                                  previousSleeps: [SleepSample],
                                  currentWorkouts: [WorkoutSession],
                                  qualityScores: [SleepQualityScore],
                                  currentEvents: [HealthEvent],
                                  previousEvents: [HealthEvent],
                                  dataDays: Int,
                                  selectedDays: Int) -> [AnalysisInsight] {
        var result: [AnalysisInsight] = []

        if let weightChange, weightChange < -0.2 {
            let comparison = previousWeightChange.map {
                $0 < -0.2 ? "，连续两个周期下降" : "，上一周期为 \(signed($0, suffix: "kg"))"
            } ?? ""
            result.append(AnalysisInsight(systemImage: "arrow.down.right.circle.fill",
                                          title: "体重下降 \(String(format: "%.1f", abs(weightChange)))kg",
                                          detail: "减脂趋势向好\(comparison)。保持当前的饮食与运动节奏即可。",
                                          tone: .positive))
        }

        // 运动：把频率 + 总量（次数 / 时长 / 消耗）讲清楚，而非只报频率。
        if !currentWorkouts.isEmpty {
            let totalMinutes = currentWorkouts.reduce(0) { $0 + $1.minutes }
            let totalKcal = currentWorkouts.reduce(0) { $0 + $1.kcal }
            let volume = "本周期共 \(currentWorkouts.count) 次、累计 \(formatMinutes(totalMinutes))、消耗 \(formatKcal(totalKcal))"
            if frequency > previousFrequency + 0.25 {
                result.append(AnalysisInsight(systemImage: "figure.run.circle.fill",
                                              title: "运动频率提升到 \(String(format: "%.1f", frequency)) 次/周",
                                              detail: "比上一周期多 \(String(format: "%.1f", frequency - previousFrequency)) 次/周。\(volume)，坚持度明显上来了。",
                                              tone: .positive))
            } else if frequency >= 3 {
                result.append(AnalysisInsight(systemImage: "checkmark.circle.fill",
                                              title: "运动保持在 \(String(format: "%.1f", frequency)) 次/周",
                                              detail: "\(volume)，规律训练的习惯正在稳定下来。",
                                              tone: .positive))
            }
        }

        // 睡眠质量评分处于优秀区间。
        if let averageScore = average(qualityScores.map(\.score)), averageScore >= 80 {
            result.append(AnalysisInsight(systemImage: "star.circle.fill",
                                          title: "睡眠质量评分 \(Int(averageScore.rounded())) 分",
                                          detail: "处于优秀区间，深睡比例与连续性都不错，恢复质量在线。",
                                          tone: .positive))
        }

        if let averageSleep, let previousAverageSleep, averageSleep > previousAverageSleep + 0.15 {
            result.append(AnalysisInsight(systemImage: "moon.stars.fill",
                                          title: "睡眠增加 \(String(format: "%.1f", averageSleep - previousAverageSleep)) 小时",
                                          detail: "日均睡眠 \(String(format: "%.1f", averageSleep)) 小时，恢复时间比上一周期更充足。",
                                          tone: .positive))
        }

        let currentEfficiency = average(currentSleeps.compactMap(\.efficiency))
        let previousEfficiency = average(previousSleeps.compactMap(\.efficiency))
        if let currentEfficiency, let previousEfficiency, currentEfficiency > previousEfficiency + 0.02 {
            result.append(AnalysisInsight(systemImage: "bed.double.fill",
                                          title: "睡眠效率提升到 \(String(format: "%.0f", currentEfficiency * 100))%",
                                          detail: "比上一周期提升 \(String(format: "%.0f", (currentEfficiency - previousEfficiency) * 100)) 个百分点，躺下后更快入睡、夜醒更少。",
                                          tone: .positive))
        }

        // 作息规律：入睡时间波动小。
        let bedtimes = currentSleeps.compactMap(\.bedtime)
        if bedtimes.count >= 4,
           let spread = clockStdDevMinutes(bedtimes, noonAnchored: true), spread < 45,
           let center = averageClockMinutes(bedtimes, noonAnchored: true) {
            result.append(AnalysisInsight(systemImage: "clock.badge.checkmark.fill",
                                          title: "作息很规律",
                                          detail: "入睡时间稳定在 \(formatClock(center)) 前后（波动约 \(Int(spread.rounded())) 分钟），稳定的生物钟对代谢和恢复都有帮助。",
                                          tone: .positive))
        }

        let currentDrinks = currentEvents.filter { $0.type == .drink }.count
        let previousDrinks = previousEvents.filter { $0.type == .drink }.count
        if currentDrinks < previousDrinks {
            result.append(AnalysisInsight(systemImage: "wineglass",
                                          title: "饮酒次数减少",
                                          detail: "比上一周期少 \(previousDrinks - currentDrinks) 次，对睡眠深度和次日恢复都是利好。",
                                          tone: .positive))
        }

        // 坚持记录：数据覆盖率高。
        if selectedDays >= 5, Double(dataDays) / Double(selectedDays) >= 0.8 {
            result.append(AnalysisInsight(systemImage: "calendar.badge.checkmark",
                                          title: "坚持记录 \(dataDays) 天",
                                          detail: "\(selectedDays) 天里有 \(dataDays) 天留下数据，愿意持续记录本身就是自律的一部分。",
                                          tone: .positive))
        }
        return result
    }

    private func warningInsights(weightChange: Double?,
                                 frequency: Double,
                                 previousFrequency: Double,
                                 averageSleep: Double?,
                                 currentSleeps: [SleepSample],
                                 currentWorkouts: [WorkoutSession],
                                 currentEvents: [HealthEvent],
                                 dataDays: Int,
                                 selectedDays: Int) -> [AnalysisInsight] {
        var result: [AnalysisInsight] = []

        if let weightChange, weightChange > 0.2 {
            result.append(AnalysisInsight(systemImage: "chart.line.uptrend.xyaxis.circle.fill",
                                          title: "体重回升 \(String(format: "%.1f", weightChange))kg",
                                          detail: "先看近期作息与运动变化，不必因为一次起伏否定整段过程。优先排查睡眠和饮食是否有波动。",
                                          tone: .warning))
        } else if let weightChange, abs(weightChange) < 0.3, selectedDays >= 21 {
            result.append(AnalysisInsight(systemImage: "equal.circle.fill",
                                          title: "体重进入平台期",
                                          detail: "本周期变化不足 0.3kg。可以从睡眠或训练结构里找突破口：换个运动类型、或把力量训练加进来提升基础代谢。",
                                          tone: .warning))
        }
        if previousFrequency > 0.5 && frequency < previousFrequency * 0.75 {
            result.append(AnalysisInsight(systemImage: "arrow.down.circle.fill",
                                          title: "运动频率回落到 \(String(format: "%.1f", frequency)) 次/周",
                                          detail: "上一周期为 \(String(format: "%.1f", previousFrequency)) 次/周，节奏有些松动。先从一次低强度的散步或拉伸重新启动。",
                                          tone: .warning))
        }

        // 单次运动时长偏短。
        if !currentWorkouts.isEmpty {
            let avgMinutes = Double(currentWorkouts.reduce(0) { $0 + $1.minutes }) / Double(currentWorkouts.count)
            if avgMinutes < 25 {
                result.append(AnalysisInsight(systemImage: "timer",
                                              title: "单次运动偏短 · 平均 \(Int(avgMinutes.rounded())) 分钟",
                                              detail: "脂肪供能通常在持续 20–30 分钟后更明显，可以试着把单次时长延长到 30 分钟以上。",
                                              tone: .warning))
            }
        }

        if let averageSleep, averageSleep < 7 {
            result.append(AnalysisInsight(systemImage: "moon.zzz.fill",
                                          title: "日均睡眠仅 \(String(format: "%.1f", averageSleep)) 小时",
                                          detail: "低于 7 小时，恢复时间偏少。优先把入睡时间往前挪 30 分钟，睡眠对减脂的影响常被低估。",
                                          tone: .warning))
        }

        // 就寝偏晚：平均入睡时间晚于 0 点。
        let bedtimes = currentSleeps.compactMap(\.bedtime)
        if bedtimes.count >= 3, let center = averageClockMinutes(bedtimes, noonAnchored: true) {
            // center 为时钟分钟（0 = 0:00）；落在 0:10–5:30 视为凌晨才睡。
            if center >= 10 && center <= 330 {
                result.append(AnalysisInsight(systemImage: "moon.haze.fill",
                                              title: "入睡偏晚 · 平均 \(formatClock(center))",
                                              detail: "经常凌晨才睡会打乱激素节律、影响第二天的食欲控制，尽量 23:30 前躺下。",
                                              tone: .warning))
            } else if let spread = clockStdDevMinutes(bedtimes, noonAnchored: true), spread >= 75 {
                // 作息不规律：入睡时间忽早忽晚。
                result.append(AnalysisInsight(systemImage: "clock.badge.exclamationmark.fill",
                                              title: "作息不太规律",
                                              detail: "入睡时间前后相差约 \(Int(spread.rounded())) 分钟，固定的上床/起床时间更利于睡眠质量。",
                                              tone: .warning))
            }
        }

        if let event = currentEvents.first(where: { $0.type.isExerciseRelated }) {
            let duration = eventDuration(event)
            result.append(AnalysisInsight(systemImage: event.type.sfSymbol,
                                          title: event.title,
                                          detail: "该事件覆盖 \(duration) 天，可能解释同期运动中断或体重波动，属于正常起伏，恢复后跟上即可。",
                                          tone: .warning))
        }

        if currentEvents.contains(where: { $0.type == .drink }),
           let efficiency = average(currentSleeps.compactMap(\.efficiency)), efficiency < 0.93 {
            result.append(AnalysisInsight(systemImage: "wineglass.fill",
                                          title: "饮酒与睡眠效率偏低同时出现",
                                          detail: "本周期平均睡眠效率 \(String(format: "%.0f", efficiency * 100))%。酒精会压低深睡比例，留意饮酒当晚的睡眠变化。",
                                          tone: .warning))
        }

        // 记录稀疏：数据覆盖率低，提醒结论参考性有限。
        if selectedDays >= 7, Double(dataDays) / Double(selectedDays) < 0.4 {
            result.append(AnalysisInsight(systemImage: "calendar.badge.exclamationmark",
                                          title: "记录偏少 · 仅 \(dataDays) 天有数据",
                                          detail: "这段时间数据较少，以上结论仅供参考。多记录几天，分析会更贴近真实状态。",
                                          tone: .warning))
        }
        return result
    }

    private func messages(for sentiment: AnalysisSentiment) -> [String] {
        switch sentiment {
        case .positive:
            return [
                "你不是在和体重较劲，而是在和昨天那个想偷懒的自己赛跑。这段日子，你赢的次数更多了。",
                "自律不是苦行，是你给未来的自己悄悄存下的底气。这一程，存得很满。",
                "小鸭看得见，你每一次迈出门的脚步，都在把更好的身体一点点养大。",
                "了不起的不是数字变小了，而是你把坚持过成了习惯。",
                "你给身体的每一次善待，它都记在心里，并在某个清晨悄悄还给你。",
                "别小看这点进步，复利从来都是先慢后快。你已经站在加速的起点上了。",
                "把目标拆成今天该做的那一件小事，你已经连续做对了好多天。",
                "汗水不会骗人，镜子也不会。你正在成为自己想成为的样子。",
                "最难的从来不是开始，而是开始之后还在坚持——而你做到了。",
                "今天的你，已经比上个月那个犹豫要不要迈步的人，强了不止一点。",
            ]
        case .negative:
            return [
                "起伏是减脂的常态。真正重要的是，你愿意翻开这页报告——那说明你还没放弃自己。",
                "反弹不可怕，别因为一次后退，就把走过的整条路都否定掉。",
                "小鸭不挑你跑得快不快，只看你今天是否愿意重新迈出那一步。",
                "把这个周期当作一次提醒，不是失败的证据。明天，我们从一顿好觉开始。",
                "身体不是一天胖起来的，也不会一周就垮掉。给它一点耐心，也给自己一点。",
                "状态有高低很正常，能在低谷里还盯着数据看的人，本身就赢了一半。",
                "不必懊恼这几天，把它当成踩了一脚刹车——歇好了，再稳稳起步。",
                "一次松懈定义不了你。决定方向的，是你接下来怎么选。",
                "潮水有涨有落，方向对了就不怕慢。小鸭陪你重新出发。",
                "别急着责怪自己，先把今晚的睡眠和明天的第一餐安排好，节奏会回来的。",
            ]
        case .neutral:
            return [
                "稳住，是一种被低估的能力。你已经做到了，接下来可以试着再推自己一把。",
                "平台期不是终点，是身体在问你：准备好迎接下一阶段了吗？",
                "把每一个平凡的坚持日子叠起来，就是别人眼里的天生自律。",
                "和昨天打平也是一种不输，但小鸭相信，你还能更好。",
                "维持本身就需要力气。能稳在这里，说明你的习惯已经立住了。",
                "身体在适应新的平衡点，这时候的耐心，往往决定下一段的高度。",
                "不前进不代表停滞，有时是在为下一次突破蓄力。",
                "换个变量试试看——睡早半小时，或加一组力量，平静的水面也会起波澜。",
                "稳定是底色，惊喜是奖励。先把底色铺好，奖励会自己来。",
                "你已经把'坚持'变成了日常，剩下的，只是再加一点点野心。",
            ]
        }
    }

    private func change(in samples: [WeightSample]) -> Double? {
        let sorted = samples.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last, first.id != last.id else { return nil }
        return (last.kg - first.kg).rounded(toPlaces: 1)
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func eventDuration(_ event: HealthEvent) -> Int {
        let end = event.endDate ?? event.startDate
        return max((calendar.dateComponents([.day], from: calendar.startOfDay(for: event.startDate),
                                            to: calendar.startOfDay(for: end)).day ?? 0) + 1, 1)
    }

    private func signed(_ value: Double, suffix: String) -> String {
        String(format: "%@%.1f%@", value > 0 ? "+" : "", value, suffix)
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = Double(minutes) / 60
        return hours >= 1 ? String(format: "%.1f 小时", hours) : "\(minutes) 分钟"
    }

    private func formatKcal(_ kcal: Double) -> String {
        if kcal >= 1_000 {
            return String(format: "%.1fK千卡", kcal / 1_000)
        }
        return "\(Int(kcal.rounded()))千卡"
    }

    /// 把时刻映射成「分钟数」。noonAnchored 以正午为锚（720=0:00），
    /// 让跨午夜的就寝时间在数值上连续、不被 0/1440 边界割裂。
    private func anchoredClockValues(_ dates: [Date], noonAnchored: Bool) -> [Double] {
        dates.map { date in
            let components = calendar.dateComponents([.hour, .minute], from: date)
            let minutes = Double((components.hour ?? 0) * 60 + (components.minute ?? 0))
            return noonAnchored ? (minutes - 720 + 1440).truncatingRemainder(dividingBy: 1440) : minutes
        }
    }

    private func averageClockMinutes(_ dates: [Date], noonAnchored: Bool) -> Double? {
        guard !dates.isEmpty else { return nil }
        let values = anchoredClockValues(dates, noonAnchored: noonAnchored)
        let average = values.reduce(0, +) / Double(values.count)
        return noonAnchored ? (average + 720).truncatingRemainder(dividingBy: 1440) : average
    }

    /// 就寝时间的离散程度（标准差，分钟）。越小越规律。
    private func clockStdDevMinutes(_ dates: [Date], noonAnchored: Bool) -> Double? {
        guard dates.count >= 2 else { return nil }
        let values = anchoredClockValues(dates, noonAnchored: noonAnchored)
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return variance.squareRoot()
    }

    private func formatClock(_ minutesOfDay: Double?) -> String {
        guard let minutesOfDay else { return "--" }
        let total = (Int(minutesOfDay.rounded()) % 1440 + 1440) % 1440
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

private extension Array {
    func inWindow(start: Date, end: Date, date: KeyPath<Element, Date>) -> [Element] {
        filter {
            let value = $0[keyPath: date]
            return value >= start && value < end
        }
    }
}
