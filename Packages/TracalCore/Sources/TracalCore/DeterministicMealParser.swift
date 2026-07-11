import Foundation

/// A small, explicit catalog entry used only when no personal match or model is
/// available. Its estimates retain uncertainty metadata for the saved entry.
public struct FallbackFoodDefinition: Sendable {
    public var name: String
    public var aliases: [String]
    public var defaultQuantity: Double
    public var defaultUnit: PortionUnit
    public var nutritionForDefaultQuantity: Nutrition
    public var gramsForDefaultQuantity: Double?
    /// For non-default units, the value is the number of default portions per
    /// one unit. Example: one milliliter of milk is `1 / 240` of its cup basis.
    public var supportedUnitScales: [PortionUnit: Double]

    public init(
        name: String,
        aliases: [String],
        defaultQuantity: Double,
        defaultUnit: PortionUnit,
        nutritionForDefaultQuantity: Nutrition,
        gramsForDefaultQuantity: Double? = nil,
        supportedUnitScales: [PortionUnit: Double] = [:]
    ) {
        self.name = name
        self.aliases = aliases
        self.defaultQuantity = defaultQuantity
        self.defaultUnit = defaultUnit
        self.nutritionForDefaultQuantity = nutritionForDefaultQuantity
        self.gramsForDefaultQuantity = gramsForDefaultQuantity
        self.supportedUnitScales = supportedUnitScales
    }

    fileprivate func scale(for quantity: Double, unit: PortionUnit) -> Double? {
        if unit == defaultUnit {
            guard defaultQuantity > 0 else { return nil }
            return quantity / defaultQuantity
        }
        return supportedUnitScales[unit].map { quantity * $0 }
    }
}

public enum FallbackParseWarningCode: String, Codable, Hashable, Sendable {
    case unmatchedFood
    case unsupportedUnit
    case unrecognizedDetail
    case emptyInput
}

public struct FallbackParseWarning: Codable, Hashable, Identifiable, Sendable {
    public var id: String { "\(code.rawValue):\(segment)" }
    public var code: FallbackParseWarningCode
    public var segment: String
    public var message: String

    public init(code: FallbackParseWarningCode, segment: String, message: String) {
        self.code = code
        self.segment = segment
        self.message = message
    }
}

public struct FallbackParseResult: Codable, Hashable, Sendable {
    public var draft: MealDraft?
    public var unmatchedSegments: [String]
    public var warnings: [FallbackParseWarning]

    public init(
        draft: MealDraft?,
        unmatchedSegments: [String],
        warnings: [FallbackParseWarning]
    ) {
        self.draft = draft
        self.unmatchedSegments = unmatchedSegments
        self.warnings = warnings
    }

    public var matchedAll: Bool {
        draft != nil && unmatchedSegments.isEmpty && warnings.isEmpty
    }
}

public struct DeterministicMealParser: Sendable {
    public var catalog: [FallbackFoodDefinition]

    public init(catalog: [FallbackFoodDefinition] = .standardFallbackCatalog) {
        self.catalog = catalog
    }

    public func parse(_ input: String, at date: Date = Date()) -> FallbackParseResult {
        let segments = Self.segments(from: input)
        guard !segments.isEmpty else {
            return FallbackParseResult(
                draft: nil,
                unmatchedSegments: [],
                warnings: [
                    FallbackParseWarning(
                        code: .emptyInput,
                        segment: input,
                        message: "Type at least one food or drink."
                    ),
                ]
            )
        }

        var items: [MealItem] = []
        var unmatched: [String] = []
        var warnings: [FallbackParseWarning] = []

        for originalSegment in segments {
            let segment = Self.normalize(originalSegment)
            guard let match = match(in: segment) else {
                unmatched.append(originalSegment)
                warnings.append(
                    FallbackParseWarning(
                        code: .unmatchedFood,
                        segment: originalSegment,
                        message: "No deterministic catalog match was found."
                    )
                )
                continue
            }

            let remainder = Self.removing(alias: match.alias, from: segment)
            switch Self.portion(from: remainder) {
            case let .success(portion):
                let quantity = portion.quantity ?? match.food.defaultQuantity
                let unit = portion.unit ?? match.food.defaultUnit
                guard let scale = match.food.scale(for: quantity, unit: unit) else {
                    unmatched.append(originalSegment)
                    warnings.append(
                        FallbackParseWarning(
                            code: .unsupportedUnit,
                            segment: originalSegment,
                            message: "That unit is not supported for \(match.food.name)."
                        )
                    )
                    continue
                }

                let usedDefaultPortion = portion.quantity == nil && portion.unit == nil
                let estimatedGrams = match.food.gramsForDefaultQuantity.map { $0 * scale }
                items.append(
                    MealItem(
                        name: match.food.name,
                        quantity: quantity,
                        unit: unit,
                        estimatedGrams: estimatedGrams,
                        nutrition: match.food.nutritionForDefaultQuantity.scaled(by: scale),
                        identificationConfidence: 0.99,
                        portionConfidence: usedDefaultPortion ? 0.60 : 0.82,
                        assumptions: ["Generic catalog estimate; brand, preparation, and portion may differ."]
                    )
                )
            case .failure:
                unmatched.append(originalSegment)
                warnings.append(
                    FallbackParseWarning(
                        code: .unrecognizedDetail,
                        segment: originalSegment,
                        message: "The food matched, but its quantity or description was not understood."
                    )
                )
            }
        }

        guard !items.isEmpty else {
            return FallbackParseResult(draft: nil, unmatchedSegments: unmatched, warnings: warnings)
        }

        var reviewReasons = ["Portions and preparation are estimated."]
        if !unmatched.isEmpty {
            reviewReasons.append("Some text could not be parsed: \(unmatched.joined(separator: ", ")).")
        }
        let confidence = items.compactMap(\.portionConfidence).min() ?? 0.5
        let draft = MealDraft(
            createdAt: date,
            source: .typedText,
            analysisRoute: .deterministicFallback,
            state: .needsReview,
            title: items.map(\.name).joined(separator: " + "),
            originalText: input,
            items: items,
            confidence: unmatched.isEmpty ? confidence : min(confidence, 0.5),
            reviewReasons: reviewReasons,
            modelVersion: "deterministic-catalog-v1"
        )
        return FallbackParseResult(draft: draft, unmatchedSegments: unmatched, warnings: warnings)
    }

    private func match(in segment: String) -> (food: FallbackFoodDefinition, alias: String)? {
        var matches: [(food: FallbackFoodDefinition, alias: String)] = []
        for food in catalog {
            for alias in food.aliases + [food.name] {
                let normalizedAlias = Self.normalize(alias)
                let haystack = " \(segment) "
                if segment == normalizedAlias || haystack.contains(" \(normalizedAlias) ") {
                    matches.append((food, normalizedAlias))
                }
            }
        }
        return matches.max { lhs, rhs in lhs.alias.count < rhs.alias.count }
    }

    private struct Portion: Sendable {
        var quantity: Double?
        var unit: PortionUnit?
    }

    private static func portion(from remainder: String) -> Result<Portion, PortionParseError> {
        let expanded = remainder.replacingOccurrences(
            of: #"([0-9.])([a-z])"#,
            with: "$1 $2",
            options: .regularExpression
        )
        let tokens = expanded.split(separator: " ").map(String.init)
        var quantity: Double?
        var unit: PortionUnit?
        var conversion = 1.0

        let ignored = Set(["a", "an", "of", "plain", "black", "boiled", "medium", "small", "large"])
        for token in tokens {
            if ignored.contains(token) { continue }
            if quantity == nil, let number = number(from: token) {
                quantity = number
                continue
            }
            if unit == nil, let parsedUnit = parsedUnit(from: token) {
                unit = parsedUnit.unit
                conversion = parsedUnit.conversion
                continue
            }
            return .failure(PortionParseError())
        }

        if quantity == nil, unit != nil { quantity = 1 }
        if let current = quantity { quantity = current * conversion }
        guard quantity.map({ $0.isFinite && $0 > 0 }) ?? true else {
            return .failure(PortionParseError())
        }
        return .success(Portion(quantity: quantity, unit: unit))
    }

    private static func number(from token: String) -> Double? {
        let words: [String: Double] = [
            "half": 0.5, "one": 1, "two": 2, "three": 3, "four": 4,
            "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        ]
        if let value = words[token] { return value }
        if token.contains("/") {
            let parts = token.split(separator: "/")
            if parts.count == 2,
               let numerator = Double(parts[0]),
               let denominator = Double(parts[1]),
               denominator != 0 {
                return numerator / denominator
            }
        }
        return Double(token)
    }

    private static func parsedUnit(from token: String) -> (unit: PortionUnit, conversion: Double)? {
        switch token {
        case "serving", "servings": (.serving, 1)
        case "piece", "pieces": (.piece, 1)
        case "slice", "slices": (.slice, 1)
        case "g", "gram", "grams": (.gram, 1)
        case "kg", "kilogram", "kilograms": (.gram, 1_000)
        case "ml", "milliliter", "milliliters", "millilitre", "millilitres": (.milliliter, 1)
        case "l", "liter", "liters", "litre", "litres": (.milliliter, 1_000)
        case "cup", "cups": (.cup, 1)
        case "tbsp", "tablespoon", "tablespoons": (.tablespoon, 1)
        case "tsp", "teaspoon", "teaspoons": (.teaspoon, 1)
        case "bowl", "bowls": (.bowl, 1)
        case "scoop", "scoops": (.scoop, 1)
        case "bottle", "bottles": (.bottle, 1)
        case "can", "cans": (.can, 1)
        case "pack", "packs", "packet", "packets": (.pack, 1)
        default: nil
        }
    }

    private static func segments(from input: String) -> [String] {
        input
            .replacingOccurrences(
                of: #"\s*(?:,|;|\+|&|\band\b)\s*"#,
                with: "|",
                options: [.regularExpression, .caseInsensitive]
            )
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9./]+"#, with: " ", options: .regularExpression)
            .split(separator: " ")
            .joined(separator: " ")
    }

    private static func removing(alias: String, from segment: String) -> String {
        var padded = " \(segment) "
        if let range = padded.range(of: " \(alias) ") {
            padded.replaceSubrange(range, with: " ")
        }
        return normalize(padded)
    }

    private struct PortionParseError: Error, Sendable {}
}

public extension Array where Element == FallbackFoodDefinition {
    static var standardFallbackCatalog: [FallbackFoodDefinition] {
        [
            FallbackFoodDefinition(
                name: "Egg",
                aliases: ["egg", "eggs", "boiled egg", "boiled eggs"],
                defaultQuantity: 1,
                defaultUnit: .piece,
                nutritionForDefaultQuantity: Nutrition(
                    caloriesKcal: 72, proteinG: 6.3, carbohydratesG: 0.4, fatG: 4.8, sodiumMg: 71
                ),
                gramsForDefaultQuantity: 50
            ),
            FallbackFoodDefinition(
                name: "Banana",
                aliases: ["banana", "bananas"],
                defaultQuantity: 1,
                defaultUnit: .piece,
                nutritionForDefaultQuantity: Nutrition(
                    caloriesKcal: 105, proteinG: 1.3, carbohydratesG: 27, fatG: 0.4,
                    fiberG: 3.1, sugarG: 14.4, sodiumMg: 1
                ),
                gramsForDefaultQuantity: 118
            ),
            FallbackFoodDefinition(
                name: "Apple",
                aliases: ["apple", "apples"],
                defaultQuantity: 1,
                defaultUnit: .piece,
                nutritionForDefaultQuantity: Nutrition(
                    caloriesKcal: 95, proteinG: 0.5, carbohydratesG: 25, fatG: 0.3,
                    fiberG: 4.4, sugarG: 19, sodiumMg: 2
                ),
                gramsForDefaultQuantity: 182
            ),
            FallbackFoodDefinition(
                name: "Toast",
                aliases: ["toast", "bread", "bread slice", "bread slices"],
                defaultQuantity: 1,
                defaultUnit: .slice,
                nutritionForDefaultQuantity: Nutrition(
                    caloriesKcal: 80, proteinG: 3, carbohydratesG: 15, fatG: 1,
                    fiberG: 1, sugarG: 1.5, sodiumMg: 145
                ),
                gramsForDefaultQuantity: 30
            ),
            FallbackFoodDefinition(
                name: "Milk",
                aliases: ["milk", "whole milk"],
                defaultQuantity: 1,
                defaultUnit: .cup,
                nutritionForDefaultQuantity: Nutrition(
                    caloriesKcal: 149, proteinG: 7.7, carbohydratesG: 11.7, fatG: 7.9,
                    sugarG: 12.3, sodiumMg: 105
                ),
                gramsForDefaultQuantity: 244,
                supportedUnitScales: [.milliliter: 1 / 240]
            ),
            FallbackFoodDefinition(
                name: "Black coffee",
                aliases: ["black coffee", "coffee"],
                defaultQuantity: 1,
                defaultUnit: .cup,
                nutritionForDefaultQuantity: Nutrition(caloriesKcal: 2, proteinG: 0.3, sodiumMg: 5),
                gramsForDefaultQuantity: 237,
                supportedUnitScales: [.milliliter: 1 / 240]
            ),
            FallbackFoodDefinition(
                name: "Chai",
                aliases: ["chai", "milk tea"],
                defaultQuantity: 1,
                defaultUnit: .cup,
                nutritionForDefaultQuantity: Nutrition(
                    caloriesKcal: 120, proteinG: 3, carbohydratesG: 20, fatG: 3,
                    sugarG: 16, sodiumMg: 55
                ),
                gramsForDefaultQuantity: 240,
                supportedUnitScales: [.milliliter: 1 / 240]
            ),
            FallbackFoodDefinition(
                name: "Cooked rice",
                aliases: ["cooked rice", "rice"],
                defaultQuantity: 1,
                defaultUnit: .cup,
                nutritionForDefaultQuantity: Nutrition(
                    caloriesKcal: 205, proteinG: 4.3, carbohydratesG: 44.5, fatG: 0.4,
                    fiberG: 0.6, sugarG: 0.1, sodiumMg: 2
                ),
                gramsForDefaultQuantity: 158
            ),
            FallbackFoodDefinition(
                name: "Chicken breast",
                aliases: ["chicken breast", "chicken"],
                defaultQuantity: 100,
                defaultUnit: .gram,
                nutritionForDefaultQuantity: Nutrition(
                    caloriesKcal: 165, proteinG: 31, fatG: 3.6, sodiumMg: 74
                ),
                gramsForDefaultQuantity: 100
            ),
            FallbackFoodDefinition(
                name: "Paneer",
                aliases: ["paneer"],
                defaultQuantity: 100,
                defaultUnit: .gram,
                nutritionForDefaultQuantity: Nutrition(
                    caloriesKcal: 265, proteinG: 18.3, carbohydratesG: 1.2, fatG: 20.8,
                    sodiumMg: 22
                ),
                gramsForDefaultQuantity: 100
            ),
            FallbackFoodDefinition(
                name: "Plain yogurt",
                aliases: ["plain yogurt", "yogurt", "curd"],
                defaultQuantity: 100,
                defaultUnit: .gram,
                nutritionForDefaultQuantity: Nutrition(
                    caloriesKcal: 61, proteinG: 3.5, carbohydratesG: 4.7, fatG: 3.3,
                    sugarG: 4.7, sodiumMg: 46
                ),
                gramsForDefaultQuantity: 100
            ),
        ]
    }
}
