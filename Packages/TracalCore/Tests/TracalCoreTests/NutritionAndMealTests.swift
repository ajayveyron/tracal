import Foundation
import Testing
@testable import TracalCore

@Suite("Nutrition and meal domain")
struct NutritionAndMealTests {
    @Test("Nutrition adds and scales every field")
    func nutritionTotalsAndScaling() {
        let eggs = Nutrition(caloriesKcal: 72, proteinG: 6.3, carbohydratesG: 0.4, fatG: 4.8)
        let toast = Nutrition(caloriesKcal: 80, proteinG: 3, carbohydratesG: 15, fatG: 1)

        let total = Nutrition.total(of: [eggs.scaled(by: 2), toast])

        #expect(abs(total.caloriesKcal - 224) < 0.0001)
        #expect(abs(total.proteinG - 15.6) < 0.0001)
        #expect(abs(total.carbohydratesG - 15.8) < 0.0001)
        #expect(abs(total.fatG - 10.6) < 0.0001)
    }

    @Test("Balance preserves signed remaining and explicit overage")
    func balancePreservesSignedRemainingAndOverage() {
        let consumed = Nutrition(caloriesKcal: 2_100, proteinG: 80, carbohydratesG: 200, fatG: 90)
        let goal = DailyGoal(
            effectiveDate: Date(timeIntervalSince1970: 0),
            caloriesKcal: 2_000,
            proteinG: 120,
            carbohydratesG: nil,
            fatG: 70
        )

        let balance = NutritionBalance(consumed: consumed, goal: goal)

        #expect(balance.calories.remaining == -100)
        #expect(balance.calories.remainingClamped == 0)
        #expect(balance.calories.overage == 100)
        #expect(balance.protein.remaining == 40)
        #expect(balance.carbohydrates.remaining == nil)
        #expect(balance.fat.overage == 20)
    }

    @Test("Draft totals are derived from item nutrition")
    func draftTotalsAreAlwaysDerivedFromItems() {
        let draft = MealDraft(
            source: .typedText,
            analysisRoute: .deterministicFallback,
            state: .needsReview,
            title: "Egg and toast",
            items: [
                MealItem(
                    name: "Egg",
                    quantity: 1,
                    unit: .piece,
                    nutrition: Nutrition(caloriesKcal: 72, proteinG: 6.3, fatG: 4.8)
                ),
                MealItem(
                    name: "Toast",
                    quantity: 1,
                    unit: .slice,
                    nutrition: Nutrition(caloriesKcal: 80, proteinG: 3, carbohydratesG: 15, fatG: 1)
                ),
            ]
        )

        #expect(draft.totals.caloriesKcal == 152)
        #expect(abs(draft.totals.proteinG - 9.3) < 0.0001)
    }

    @Test("A valid review draft confirms without changing identity")
    func validDraftConfirmsAndKeepsIdentity() throws {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 123)
        let draft = MealDraft(
            id: id,
            source: .manual,
            analysisRoute: .manual,
            title: "Banana",
            items: [
                MealItem(
                    name: "Banana",
                    quantity: 1,
                    unit: .piece,
                    nutrition: Nutrition(caloriesKcal: 105, carbohydratesG: 27)
                ),
            ]
        )

        let entry = try draft.confirmed(loggedAt: date)

        #expect(entry.id == id)
        #expect(entry.loggedAt == date)
        #expect(entry.totals.caloriesKcal == 105)
    }

    @Test("An invalid or in-flight draft cannot confirm")
    func invalidDraftCannotConfirm() {
        let draft = MealDraft(
            source: .typedText,
            analysisRoute: .onDeviceText,
            state: .analyzing,
            title: "",
            items: []
        )

        do {
            _ = try draft.confirmed()
            Issue.record("Expected confirmation to fail")
        } catch let error as MealConfirmationError {
            #expect(error.report.errors.contains { $0.code == .emptyMeal })
            #expect(error.report.errors.contains { $0.code == .analysisNotReady })
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("A confirmed analysis is terminal")
    func analysisStateRejectsChangesAfterConfirmation() throws {
        var draft = MealDraft(
            source: .manual,
            analysisRoute: .manual,
            state: .needsReview,
            title: "Coffee"
        )

        try draft.transition(to: .confirmed)
        #expect(throws: AnalysisTransitionError.self) {
            try draft.transition(to: .analyzing)
        }
    }

    @Test("Validation rejects non-finite values and missing custom units")
    func validationRejectsInvalidNumbersAndMissingCustomUnit() {
        let item = MealItem(
            name: "Mystery food",
            quantity: .infinity,
            unit: .custom,
            nutrition: Nutrition(caloriesKcal: -.infinity),
            identificationConfidence: 1.2
        )

        let report = MealValidator.validate(item)

        #expect(!report.isValid)
        #expect(report.errors.contains { $0.code == .invalidQuantity })
        #expect(report.errors.contains { $0.code == .customUnitMissing })
        #expect(report.errors.contains { $0.code == .invalidNutrition })
        #expect(report.errors.contains { $0.code == .invalidConfidence })
    }

    @Test("Codable round trip preserves the provider-neutral contract")
    func codableRoundTrip() throws {
        let draft = MealDraft(
            analysisID: UUID(),
            source: .cameraPhoto,
            analysisRoute: .vertexFallback,
            state: .needsReview,
            title: "Paneer",
            items: [
                MealItem(
                    name: "Paneer",
                    quantity: 100,
                    unit: .gram,
                    nutrition: Nutrition(caloriesKcal: 265, proteinG: 18.3, fatG: 20.8),
                    assumptions: ["Oil not included"]
                ),
            ],
            promptVersion: "nutrition-v1",
            modelVersion: "fixture"
        )

        let encoded = try JSONEncoder().encode(draft)
        let decoded = try JSONDecoder().decode(MealDraft.self, from: encoded)

        #expect(decoded == draft)
    }
}
