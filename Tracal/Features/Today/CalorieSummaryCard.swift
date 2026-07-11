import SwiftUI

struct CalorieSummaryCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var calorieFontSize: CGFloat = 52

    let summary: DailyNutritionSummary
    let onSetGoal: () -> Void

    private var presentation: (label: String, value: Double) {
        guard let remaining = summary.caloriesRemaining else {
            return ("Consumed", summary.consumed.caloriesKcal)
        }
        return remaining >= 0 ? ("Remaining", remaining) : ("Over", abs(remaining))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TracalSpace.large) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: TracalSpace.medium) {
                        calorieText
                        progressGauge
                    }
                } else {
                    HStack(alignment: .center, spacing: TracalSpace.large) {
                        calorieText
                            .frame(maxWidth: .infinity, alignment: .leading)
                        progressGauge
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(presentation.label)
            .accessibilityValue(accessibilitySummary)

            if let target = summary.calorieTarget {
                VStack(alignment: .leading, spacing: TracalSpace.small) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(TracalColor.backgroundTertiary)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(TracalColor.accent)
                                    .frame(width: proxy.size.width * summary.calorieProgress)
                            }
                    }
                    .frame(height: 7)

                    Text("\(summary.consumed.caloriesKcal.formatted(.number.precision(.fractionLength(0)))) of \(target.formatted(.number.precision(.fractionLength(0)))) kcal")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(TracalColor.textSecondary)
                }
                .accessibilityHidden(true)
            } else {
                Button(action: onSetGoal) {
                    Text("Set a daily goal")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                    .buttonStyle(.tracalGlass)
            }
        }
        .padding(TracalSpace.large)
        .tonalSurface()
        .accessibilityElement(children: .contain)
    }

    private var calorieText: some View {
        VStack(alignment: .leading, spacing: TracalSpace.xSmall) {
            Text(presentation.label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TracalColor.textSecondary)

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 0) {
                        calorieNumber
                        calorieUnit
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: TracalSpace.xSmall) {
                        calorieNumber
                        calorieUnit
                    }
                }
            }
        }
    }

    private var calorieNumber: some View {
        Text(presentation.value, format: .number.precision(.fractionLength(0)))
            .font(.system(size: calorieFontSize, weight: .bold, design: .rounded))
            .monospacedDigit()
            .contentTransition(reduceMotion ? .identity : .numericText())
            .foregroundStyle(TracalColor.textPrimary)
    }

    private var calorieUnit: some View {
        Text("kcal")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(TracalColor.textSecondary)
    }

    private var progressGauge: some View {
        ZStack {
            Circle()
                .stroke(TracalColor.backgroundTertiary, lineWidth: 10)
            Circle()
                .trim(from: 0, to: summary.calorieProgress)
                .stroke(
                    TracalColor.accent,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(
                    reduceMotion ? nil : .snappy(duration: 0.35),
                    value: summary.calorieProgress
                )
            Image(systemName: "flame.fill")
                .font(.headline)
                .foregroundStyle(TracalColor.accent)
        }
        .frame(width: 88, height: 88)
        .accessibilityHidden(true)
    }

    private var accessibilitySummary: String {
        let value = presentation.value.formatted(.number.precision(.fractionLength(0)))
        guard let target = summary.calorieTarget else {
            return "\(value) kilocalories consumed"
        }
        let consumed = summary.consumed.caloriesKcal.formatted(
            .number.precision(.fractionLength(0))
        )
        let targetText = target.formatted(.number.precision(.fractionLength(0)))
        return "\(value) kilocalories. \(consumed) of \(targetText) consumed"
    }
}
