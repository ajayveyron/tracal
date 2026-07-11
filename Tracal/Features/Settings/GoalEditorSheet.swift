import SwiftData
import SwiftUI

struct GoalEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let existingGoal: DailyGoal?

    @State private var calorieTarget = ""
    @State private var proteinTarget = ""
    @State private var carbohydrateTarget = ""
    @State private var fatTarget = ""
    @FocusState private var focusedField: GoalField?

    private var parsedCalorieTarget: Double? {
        parse(calorieTarget).flatMap { $0 > 0 ? $0 : nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TracalSpace.xLarge) {
                    VStack(alignment: .leading, spacing: TracalSpace.small) {
                        Text("Daily goal")
                            .font(.largeTitle.bold())
                            .accessibilityAddTraits(.isHeader)
                        Text("Calories are required. Macros can stay blank.")
                            .font(.subheadline)
                            .foregroundStyle(TracalColor.textSecondary)
                    }

                    VStack(spacing: TracalSpace.small) {
                        GoalTextField(
                            title: "Calories",
                            unit: "kcal",
                            text: $calorieTarget,
                            field: .calories,
                            focusedField: $focusedField
                        )
                        GoalTextField(
                            title: "Protein",
                            unit: "g",
                            text: $proteinTarget,
                            field: .protein,
                            focusedField: $focusedField
                        )
                        GoalTextField(
                            title: "Carbs",
                            unit: "g",
                            text: $carbohydrateTarget,
                            field: .carbohydrate,
                            focusedField: $focusedField
                        )
                        GoalTextField(
                            title: "Fat",
                            unit: "g",
                            text: $fatTarget,
                            field: .fat,
                            focusedField: $focusedField
                        )
                    }

                    Text("Changes take effect today, so older days keep the goal you used then.")
                        .font(.footnote)
                        .foregroundStyle(TracalColor.textSecondary)

                    Button(action: save) {
                        Text("Save goal")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 64)
                    }
                        .buttonStyle(.tracalGlassProminent)
                        .disabled(parsedCalorieTarget == nil)
                        .accessibilityIdentifier("goal.save")
                }
                .frame(maxWidth: TracalMetric.contentMaxWidth)
                .padding(TracalSpace.large)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(TracalColor.backgroundPrimary.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(TracalColor.accent)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                        .accessibilityIdentifier("keyboard.done")
                }
            }
        }
        .onAppear(perform: loadExistingGoal)
    }

    private func loadExistingGoal() {
        guard let existingGoal else {
            focusedField = .calories
            return
        }
        calorieTarget = format(existingGoal.calorieTarget)
        proteinTarget = existingGoal.proteinTargetG.map(format) ?? ""
        carbohydrateTarget = existingGoal.carbohydrateTargetG.map(format) ?? ""
        fatTarget = existingGoal.fatTargetG.map(format) ?? ""
    }

    private func save() {
        guard let calories = parsedCalorieTarget else { return }
        let today = Calendar.current.startOfDay(for: .now)

        if let existingGoal,
           Calendar.current.isDate(existingGoal.effectiveDate, inSameDayAs: today) {
            existingGoal.calorieTarget = calories
            existingGoal.proteinTargetG = parse(proteinTarget)
            existingGoal.carbohydrateTargetG = parse(carbohydrateTarget)
            existingGoal.fatTargetG = parse(fatTarget)
        } else {
            modelContext.insert(
                DailyGoal(
                    effectiveDate: today,
                    calorieTarget: calories,
                    proteinTargetG: parse(proteinTarget),
                    carbohydrateTargetG: parse(carbohydrateTarget),
                    fatTargetG: parse(fatTarget)
                )
            )
        }

        try? modelContext.save()
        dismiss()
    }

    private func parse(_ value: String) -> Double? {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return Double(value.replacingOccurrences(of: ",", with: ".")).map { max(0, $0) }
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(value.rounded() == value ? 0 : 1)))
    }
}

private enum GoalField: Hashable {
    case calories
    case protein
    case carbohydrate
    case fat

    var next: GoalField? {
        switch self {
        case .calories: .protein
        case .protein: .carbohydrate
        case .carbohydrate: .fat
        case .fat: nil
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .calories: "goal.calories"
        case .protein: "goal.protein"
        case .carbohydrate: "goal.carbohydrate"
        case .fat: "goal.fat"
        }
    }
}

private struct GoalTextField: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let unit: String
    @Binding var text: String
    let field: GoalField
    var focusedField: FocusState<GoalField?>.Binding

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: TracalSpace.small) {
                    fieldTitle
                    fieldInput
                }
            } else {
                HStack(spacing: TracalSpace.medium) {
                    fieldTitle
                    Spacer()
                    fieldInput
                }
            }
        }
        .padding(TracalSpace.medium)
        .tonalSurface()
    }

    private var fieldTitle: some View {
        Text(title)
            .font(.body.weight(.medium))
            .accessibilityHidden(true)
    }

    private var fieldInput: some View {
        HStack(alignment: .firstTextBaseline, spacing: TracalSpace.small) {
            TextField(field == .calories ? "Required" : "Optional", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.title3.weight(.semibold).monospacedDigit())
                .focused(focusedField, equals: field)
                .submitLabel(field.next == nil ? .done : .next)
                .onSubmit { focusedField.wrappedValue = field.next }
                .accessibilityLabel(title)
                .accessibilityHint(field == .calories ? "Required, in kilocalories" : "Optional, in grams")
                .accessibilityIdentifier(field.accessibilityIdentifier)
                .frame(minWidth: 84, maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 180)
            Text(unit)
                .font(.subheadline)
                .foregroundStyle(TracalColor.textSecondary)
                .accessibilityHidden(true)
        }
    }
}
