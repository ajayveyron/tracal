import Foundation

public enum ValidationSeverity: String, Codable, Hashable, Sendable {
    case warning
    case error
}

public enum ValidationCode: String, Codable, Hashable, Sendable {
    case emptyMealTitle
    case emptyMeal
    case emptyItemName
    case invalidQuantity
    case invalidEstimatedGrams
    case invalidNutrition
    case invalidConfidence
    case invalidGoal
    case customUnitMissing
    case analysisNotReady
}

public struct ValidationIssue: Codable, Hashable, Identifiable, Sendable {
    public var id: String { "\(code.rawValue):\(field):\(itemID?.uuidString ?? "meal")" }
    public var code: ValidationCode
    public var severity: ValidationSeverity
    public var field: String
    public var message: String
    public var itemID: UUID?

    public init(
        code: ValidationCode,
        severity: ValidationSeverity = .error,
        field: String,
        message: String,
        itemID: UUID? = nil
    ) {
        self.code = code
        self.severity = severity
        self.field = field
        self.message = message
        self.itemID = itemID
    }
}

public struct ValidationReport: Codable, Hashable, Sendable {
    public var issues: [ValidationIssue]

    public init(issues: [ValidationIssue] = []) {
        self.issues = issues
    }

    public var isValid: Bool {
        !issues.contains { $0.severity == .error }
    }

    public var canConfirm: Bool { isValid }

    public var errors: [ValidationIssue] {
        issues.filter { $0.severity == .error }
    }

    public var warnings: [ValidationIssue] {
        issues.filter { $0.severity == .warning }
    }
}

public enum MealValidator {
    public static func validate(_ draft: MealDraft, forConfirmation: Bool = false) -> ValidationReport {
        var issues = mealIssues(title: draft.title, items: draft.items, confidence: draft.confidence)
        if forConfirmation, draft.state == .queued || draft.state == .analyzing || draft.state == .failed {
            issues.append(
                ValidationIssue(
                    code: .analysisNotReady,
                    field: "state",
                    message: "Analysis must finish before this meal can be confirmed."
                )
            )
        }
        return ValidationReport(issues: issues)
    }

    public static func validate(_ entry: MealEntry) -> ValidationReport {
        ValidationReport(issues: mealIssues(title: entry.title, items: entry.items, confidence: entry.confidence))
    }

    public static func validate(_ item: MealItem) -> ValidationReport {
        ValidationReport(issues: itemIssues(item))
    }

    public static func validate(_ goal: DailyGoal) -> ValidationReport {
        var issues: [ValidationIssue] = []
        if !goal.caloriesKcal.isFinite || goal.caloriesKcal <= 0 {
            issues.append(invalidGoalIssue(field: "caloriesKcal"))
        }
        for (field, value) in [
            ("proteinG", goal.proteinG),
            ("carbohydratesG", goal.carbohydratesG),
            ("fatG", goal.fatG),
        ] {
            if let value, !value.isFinite || value < 0 {
                issues.append(invalidGoalIssue(field: field))
            }
        }
        return ValidationReport(issues: issues)
    }

    public static func validate(_ nutrition: Nutrition) -> ValidationReport {
        ValidationReport(issues: nutritionIssues(nutrition, itemID: nil))
    }

    private static func mealIssues(title: String, items: [MealItem], confidence: Double?) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                ValidationIssue(code: .emptyMealTitle, field: "title", message: "Meal title cannot be empty.")
            )
        }
        if items.isEmpty {
            issues.append(
                ValidationIssue(code: .emptyMeal, field: "items", message: "Add at least one food item.")
            )
        }
        if let confidence, !isConfidence(confidence) {
            issues.append(
                ValidationIssue(
                    code: .invalidConfidence,
                    field: "confidence",
                    message: "Confidence must be between 0 and 1."
                )
            )
        }
        issues.append(contentsOf: items.flatMap(itemIssues))
        return issues
    }

    private static func itemIssues(_ item: MealItem) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                ValidationIssue(
                    code: .emptyItemName,
                    field: "name",
                    message: "Food name cannot be empty.",
                    itemID: item.id
                )
            )
        }
        if !item.quantity.isFinite || item.quantity <= 0 {
            issues.append(
                ValidationIssue(
                    code: .invalidQuantity,
                    field: "quantity",
                    message: "Quantity must be greater than zero.",
                    itemID: item.id
                )
            )
        }
        if let grams = item.estimatedGrams, !grams.isFinite || grams <= 0 {
            issues.append(
                ValidationIssue(
                    code: .invalidEstimatedGrams,
                    field: "estimatedGrams",
                    message: "Estimated grams must be greater than zero.",
                    itemID: item.id
                )
            )
        }
        if item.unit == .custom,
           item.customUnit?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            issues.append(
                ValidationIssue(
                    code: .customUnitMissing,
                    field: "customUnit",
                    message: "A custom unit needs a name.",
                    itemID: item.id
                )
            )
        }
        for (field, confidence) in [
            ("identificationConfidence", item.identificationConfidence),
            ("portionConfidence", item.portionConfidence),
        ] {
            if let confidence, !isConfidence(confidence) {
                issues.append(
                    ValidationIssue(
                        code: .invalidConfidence,
                        field: field,
                        message: "Confidence must be between 0 and 1.",
                        itemID: item.id
                    )
                )
            }
        }
        issues.append(contentsOf: nutritionIssues(item.nutrition, itemID: item.id))
        return issues
    }

    private static func nutritionIssues(_ nutrition: Nutrition, itemID: UUID?) -> [ValidationIssue] {
        let values = [
            ("caloriesKcal", nutrition.caloriesKcal),
            ("proteinG", nutrition.proteinG),
            ("carbohydratesG", nutrition.carbohydratesG),
            ("fatG", nutrition.fatG),
            ("fiberG", nutrition.fiberG),
            ("sugarG", nutrition.sugarG),
            ("sodiumMg", nutrition.sodiumMg),
        ]
        return values.compactMap { field, value in
            guard !value.isFinite || value < 0 else { return nil }
            return ValidationIssue(
                code: .invalidNutrition,
                field: field,
                message: "Nutrition values must be finite and nonnegative.",
                itemID: itemID
            )
        }
    }

    private static func invalidGoalIssue(field: String) -> ValidationIssue {
        ValidationIssue(
            code: .invalidGoal,
            field: field,
            message: "Goal values must be finite and nonnegative; calories must be greater than zero."
        )
    }

    private static func isConfidence(_ value: Double) -> Bool {
        value.isFinite && (0...1).contains(value)
    }
}
