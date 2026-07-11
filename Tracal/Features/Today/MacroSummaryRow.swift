import SwiftUI

struct MacroSummaryRow: View {
    let summary: DailyNutritionSummary

    private var macros: [MacroPresentation] {
        [
            MacroPresentation(
                name: "Protein",
                consumed: summary.consumed.proteinG,
                target: summary.proteinTargetG,
                color: TracalColor.protein
            ),
            MacroPresentation(
                name: "Carbs",
                consumed: summary.consumed.carbohydrateG,
                target: summary.carbohydrateTargetG,
                color: TracalColor.carbohydrate
            ),
            MacroPresentation(
                name: "Fat",
                consumed: summary.consumed.fatG,
                target: summary.fatTargetG,
                color: TracalColor.fat
            )
        ]
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: TracalSpace.small) {
                ForEach(macros) { macro in
                    MacroCard(macro: macro)
                }
            }

            VStack(spacing: TracalSpace.small) {
                ForEach(macros) { macro in
                    MacroCard(macro: macro, compact: true)
                }
            }
        }
    }
}

private struct MacroPresentation: Identifiable {
    let name: String
    let consumed: Double
    let target: Double?
    let color: Color

    var id: String { name }

    var primaryValue: Double {
        target.map { max(0, $0 - consumed) } ?? consumed
    }

    var secondaryLabel: String {
        target == nil ? "logged" : "left"
    }

    var progress: Double {
        guard let target, target > 0 else { return 0 }
        return min(max(consumed / target, 0), 1)
    }
}

private struct MacroCard: View {
    let macro: MacroPresentation
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: TracalSpace.small) {
            if compact {
                HStack(alignment: .firstTextBaseline) {
                    label
                    Spacer()
                    value
                }
            } else {
                label
                value
            }

            GeometryReader { proxy in
                Capsule()
                    .fill(TracalColor.backgroundTertiary)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(macro.color)
                            .frame(width: max(6, proxy.size.width * macro.progress))
                    }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TracalSpace.medium)
        .tonalSurface()
        .accessibilityElement(children: .combine)
    }

    private var label: some View {
        Text(macro.name)
            .font(.caption.weight(.medium))
            .foregroundStyle(TracalColor.textSecondary)
    }

    private var value: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(macro.primaryValue, format: .number.precision(.fractionLength(0)))
                .font(.title3.weight(.bold))
                .monospacedDigit()
            Text("g \(macro.secondaryLabel)")
                .font(.caption)
                .foregroundStyle(TracalColor.textSecondary)
        }
        .foregroundStyle(TracalColor.textPrimary)
    }
}

