import Foundation

/// Parses values the user or a printed label states explicitly. It never
/// guesses nutrition from a food name.
public struct DeterministicMealParser: Sendable {
    public init() {}

    public func parseExplicitText(
        _ text: String,
        loggedAt: Date,
        source: MealInputSource
    ) -> AnalyzedMealDraft? {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return nil }
        guard let calories = calories(in: normalizedText) else { return nil }

        let protein = nutrient(
            in: normalizedText,
            names: ["protein"]
        ) ?? 0
        let carbohydrates = nutrient(
            in: normalizedText,
            names: ["total\\s+carbohydrates?", "carbohydrates?", "carbs?"]
        ) ?? 0
        let fat = nutrient(
            in: normalizedText,
            names: ["total\\s+fat", "fat"]
        ) ?? 0
        let containsAllMacros = protein > 0 && carbohydrates > 0 && fat > 0
        let name = explicitTextTitle(from: normalizedText)

        return AnalyzedMealDraft(
            loggedAt: loggedAt,
            title: name,
            inputSource: source,
            analysisRoute: .deterministic,
            items: [
                AnalyzedFoodItem(
                    name: name,
                    nutrition: NutritionValues(
                        caloriesKcal: calories,
                        proteinGrams: protein,
                        carbohydrateGrams: carbohydrates,
                        fatGrams: fat
                    ),
                    identificationConfidence: 1,
                    portionConfidence: 1,
                    assumptions: containsAllMacros
                        ? []
                        : ["Only nutrition values stated in the description were included."]
                )
            ],
            needsReview: true,
            reviewReason: containsAllMacros
                ? "Nutrition values came directly from the description."
                : "Macros not included in the description are recorded as zero.",
            promptVersion: "deterministic-explicit-v1"
        )
    }

    public func parseNutritionLabel(
        _ recognition: RecognizedNutritionText,
        loggedAt: Date,
        source: MealInputSource
    ) -> AnalyzedMealDraft? {
        let text = recognition.text
        guard looksLikeNutritionLabel(text), let calories = labelCalories(in: text) else {
            return nil
        }

        let protein = nutrient(in: text, names: ["protein"]) ?? 0
        let carbohydrates = nutrient(
            in: text,
            names: ["total\\s+carbohydrates?", "carbohydrates?", "carbs?"]
        ) ?? 0
        let fat = nutrient(in: text, names: ["total\\s+fat"]) ?? 0
        let servingGrams = firstValue(
            in: text,
            patterns: [
                #"serving\s+size[^\n\d]{0,20}([\d.,]+)\s*g\b"#,
                #"takaran\s+saji[^\n\d]{0,20}([\d.,]+)\s*g\b"#
            ]
        )
        let confidence = Double(recognition.meanConfidence).unitInterval

        return AnalyzedMealDraft(
            loggedAt: loggedAt,
            title: "Nutrition label",
            inputSource: source,
            analysisRoute: .visionNutritionLabel,
            items: [
                AnalyzedFoodItem(
                    name: "Labelled food",
                    quantity: 1,
                    unit: "serving",
                    estimatedGrams: servingGrams,
                    nutrition: NutritionValues(
                        caloriesKcal: calories,
                        proteinGrams: protein,
                        carbohydrateGrams: carbohydrates,
                        fatGrams: fat
                    ),
                    identificationConfidence: confidence,
                    portionConfidence: servingGrams == nil ? 0.65 : confidence,
                    assumptions: ["Values are per serving; the consumed serving count may differ."]
                )
            ],
            needsReview: true,
            reviewReason: "The product name and consumed serving count may need correction.",
            promptVersion: "vision-label-v1",
            modelVersion: "Vision"
        )
    }

    private func looksLikeNutritionLabel(_ text: String) -> Bool {
        let normalized = text.lowercased()
        let anchors = [
            "nutrition facts",
            "amount per serving",
            "total fat",
            "total carbohydrate",
            "protein",
            "serving size",
            "informasi nilai gizi",
            "takaran saji"
        ]
        return anchors.filter(normalized.contains).count >= 2
    }

    private func labelCalories(in text: String) -> Double? {
        firstValue(
            in: text,
            patterns: [
                #"^(?!.*calories?\s+from\s+fat)[^\n]{0,40}(?:calories?|energi\s+total|total\s+energy)[^\n\d]{0,24}([\d.,]+)\s*(?:kcal)?"#,
                #"^\s*(?:total\s+)?calories?(?!\s+from\s+fat)[^\n\d]{0,24}([\d.,]+)\s*(?:kcal)?"#,
                #"^\s*(?:energi\s+total|total\s+energy)[^\n\d]{0,24}([\d.,]+)\s*(?:kcal)?"#
            ]
        )
    }

    private func calories(in text: String) -> Double? {
        firstValue(
            in: text,
            patterns: [
                #"([\d.,]+)\s*(?:kcal|calories?)(?!\s+from\s+fat)"#,
                #"(?:kcal|calories?)(?!\s+from\s+fat)[^\d]{0,12}([\d.,]+)"#
            ]
        )
    }

    private func nutrient(in text: String, names: [String]) -> Double? {
        for name in names {
            let patterns = [
                "(?:^|\\n)[^\\n]{0,36}(?:\(name))[^\\n\\d]{0,20}([\\d.,]+)\\s*g\\b",
                "([\\d.,]+)\\s*g\\s*(?:of\\s+)?(?:\(name))\\b"
            ]
            if let value = firstValue(in: text, patterns: patterns) {
                return value
            }
        }
        return nil
    }

    private func firstValue(in text: String, patterns: [String]) -> Double? {
        let searchRange = NSRange(text.startIndex..<text.endIndex, in: text)

        for pattern in patterns {
            guard let expression = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive, .anchorsMatchLines]
            ), let match = expression.firstMatch(in: text, range: searchRange),
               match.numberOfRanges > 1,
               let valueRange = Range(match.range(at: 1), in: text)
            else {
                continue
            }

            let raw = String(text[valueRange]).replacingOccurrences(of: ",", with: ".")
            if let value = Double(raw), value.isFinite, value >= 0 {
                return value
            }
        }
        return nil
    }

    private func explicitTextTitle(from text: String) -> String {
        let firstSegment = text
            .split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? text
        let pattern = #"\s*[\d.,]+\s*(?:kcal|calories?).*$"#
        let range = NSRange(firstSegment.startIndex..<firstSegment.endIndex, in: firstSegment)
        let cleaned: String
        if let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            cleaned = expression.stringByReplacingMatches(
                in: firstSegment,
                range: range,
                withTemplate: ""
            )
        } else {
            cleaned = firstSegment
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Meal"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension Double {
    var unitInterval: Double {
        guard isFinite else { return 0 }
        return min(1, max(0, self))
    }
}
