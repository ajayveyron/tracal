import SwiftUI

struct CalorieSummaryCard: View {
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
            HStack(alignment: .center, spacing: TracalSpace.large) {
                VStack(alignment: .leading, spacing: TracalSpace.xSmall) {
                    Text(presentation.label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(TracalColor.textSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: TracalSpace.xSmall) {
                        Text(presentation.value, format: .number.precision(.fractionLength(0)))
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .foregroundStyle(TracalColor.textPrimary)
                        Text("kcal")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(TracalColor.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

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
                        .animation(.snappy(duration: 0.35), value: summary.calorieProgress)
                    Image(systemName: "flame.fill")
                        .font(.headline)
                        .foregroundStyle(TracalColor.accent)
                }
                .frame(width: 88, height: 88)
                .accessibilityHidden(true)
            }

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
        .accessibilityElement(children: .combine)
    }
}
