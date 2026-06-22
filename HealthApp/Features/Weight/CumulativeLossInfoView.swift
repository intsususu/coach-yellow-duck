// CumulativeLossInfoView.swift
// 「累计减少」口径说明：只累加下坡段（峰→谷）的减少，并逐段列出日期区间与减少量。

import SwiftUI

struct CumulativeLossInfoView: View {
    @Environment(\.dismiss) private var dismiss
    let statistics: WeightStatistics

    private var segments: [WeightLossSegment] { statistics.lossSegments }
    private var total: Double { statistics.cumulativeLoss ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    totalCard
                    explanationCard
                    segmentsCard
                }
                .padding(20)
            }
            .background(Color.appBg.ignoresSafeArea())
            .navigationTitle("累计减少")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    /// 顶部：累计减少总量。
    private var totalCard: some View {
        VStack(spacing: 6) {
            Text("累计减少")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", total))
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundColor(.successGreen)
                Text("kg")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.successGreen.opacity(0.7))
            }
            Text("由 \(segments.count) 段下坡累加")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.weightCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// 口径说明。
    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("怎么算的")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.textPrimary)
            Text("只统计「下坡段」：从每一个体重高峰回落到随后低谷的减少量相加，中间的回升期不计入。只有反弹超过 3kg 才算一次真正的转折，借此过滤日常体重波动和称重误差，保留真正的大段减重。")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// 各下坡段明细：日期区间 + 减少量。
    @ViewBuilder
    private var segmentsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("各段下坡")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.textPrimary)

            if segments.isEmpty {
                Text("暂无超过 3kg 的下坡段")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                    segmentRow(segment)
                    if index < segments.count - 1 {
                        Divider().background(Color.hairline)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func segmentRow(_ segment: WeightLossSegment) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(Self.dateText(segment.startDate)) – \(Self.dateText(segment.endDate))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text("\(Self.kgText(segment.peakKg)) → \(Self.kgText(segment.valleyKg)) kg")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.textMuted)
            }
            Spacer()
            Text("−\(Self.kgText(segment.drop)) kg")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.successGreen)
        }
        .padding(.vertical, 6)
    }

    private static func kgText(_ value: Double) -> String { String(format: "%.1f", value) }

    private static func dateText(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()
}
