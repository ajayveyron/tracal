import Testing
@testable import TracalCore

@Suite("Deterministic meal parser")
struct DeterministicMealParserTests {
    private let parser = DeterministicMealParser()

    @Test("Simple quantities and conjunctions")
    func parsesSimpleQuantitiesAndConjunctions() throws {
        let result = parser.parse("2 eggs and a banana")
        let draft = try #require(result.draft)

        #expect(result.matchedAll)
        #expect(draft.analysisRoute == .deterministicFallback)
        #expect(draft.state == .needsReview)
        #expect(draft.items.count == 2)
        #expect(draft.items[0].quantity == 2)
        #expect(abs(draft.totals.caloriesKcal - 249) < 0.0001)
        #expect(abs(draft.totals.proteinG - 13.9) < 0.0001)
    }

    @Test("Attached metric units scale nutrition")
    func parsesAttachedMetricUnitsAndScalesNutrition() throws {
        let result = parser.parse("250ml milk, 200g paneer")
        let draft = try #require(result.draft)

        #expect(result.matchedAll)
        #expect(draft.items[0].unit == .milliliter)
        #expect(draft.items[0].quantity == 250)
        #expect(draft.items[1].quantity == 200)
        #expect(abs(draft.items[1].nutrition.caloriesKcal - 530) < 0.0001)
        #expect(abs(draft.totals.caloriesKcal - 685.208333) < 0.0001)
    }

    @Test("Partial matches remain reviewable and report unmatched text")
    func partialMatchReturnsReviewableDraftAndWarnings() throws {
        let result = parser.parse("coffee and mystery pastry")
        let draft = try #require(result.draft)

        #expect(!result.matchedAll)
        #expect(result.unmatchedSegments == ["mystery pastry"])
        #expect(result.warnings.first?.code == .unmatchedFood)
        #expect(draft.items.count == 1)
        #expect(draft.confidence == 0.5)
        #expect(draft.reviewReasons.contains { $0.contains("mystery pastry") })
    }

    @Test("Unknown and empty input never invent meals")
    func unknownAndEmptyInputDoNotInventMeals() {
        let unknown = parser.parse("spicy mystery casserole")
        let empty = parser.parse("   ")

        #expect(unknown.draft == nil)
        #expect(unknown.warnings.first?.code == .unmatchedFood)
        #expect(empty.draft == nil)
        #expect(empty.warnings.first?.code == .emptyInput)
    }

    @Test("Unsupported units are not silently converted")
    func unsupportedUnitDoesNotSilentlyConvert() {
        let result = parser.parse("2 cups eggs")

        #expect(result.draft == nil)
        #expect(result.warnings.first?.code == .unsupportedUnit)
    }

    @Test("The catalog can be replaced with a personal fallback")
    func catalogCanBeReplacedForPersonalUse() throws {
        let custom = FallbackFoodDefinition(
            name: "Home shake",
            aliases: ["home shake"],
            defaultQuantity: 1,
            defaultUnit: .serving,
            nutritionForDefaultQuantity: Nutrition(caloriesKcal: 320, proteinG: 40)
        )
        let parser = DeterministicMealParser(catalog: [custom])

        let draft = try #require(parser.parse("2 servings home shake").draft)

        #expect(draft.totals.caloriesKcal == 640)
        #expect(draft.totals.proteinG == 80)
    }
}
