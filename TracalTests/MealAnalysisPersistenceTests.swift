import SwiftData
import XCTest
@testable import Tracal

@MainActor
final class MealAnalysisPersistenceTests: XCTestCase {
    func testRouterCapturesWrittenTextAndPhotoHintCentrally() async throws {
        let router = DefaultMealAnalysisRouter(provider: PersistenceProviderAnalyzer())
        let typedText = "Paneer wrap with extra mint chutney"
        let typedDraft = try await router.analyze(
            MealAnalysisRequest(
                loggedAt: .now,
                source: .typedText,
                input: .text(typedText)
            )
        )

        XCTAssertEqual(typedDraft.originalDescription, typedText)

        let photoHint = "I ate the whole bowl"
        let protectedPath = "ProtectedMealDrafts/fixture.jpg"
        let photoDraft = try await router.analyze(
            MealAnalysisRequest(
                loggedAt: .now,
                source: .photoLibrary,
                input: .photo(
                    SanitizedMealImage(data: Data([0]), pixelWidth: 1, pixelHeight: 1),
                    hint: photoHint
                ),
                protectedImagePath: protectedPath
            )
        )

        XCTAssertEqual(photoDraft.originalDescription, photoHint)
        XCTAssertEqual(photoDraft.protectedImagePath, protectedPath)
    }

    func testConfirmationAndMappingPreserveAnalysisMetadata() throws {
        var draft = makeDraft()

        draft.normalizeForConfirmation()
        let entry = MealEntry(confirmedDraft: draft)

        XCTAssertFalse(draft.needsReview)
        XCTAssertEqual(draft.reviewReason, "Oil quantity was estimated.")
        XCTAssertEqual(entry.reviewReason, draft.reviewReason)
        XCTAssertEqual(entry.promptVersion, "vertex-meal-v1")
        XCTAssertEqual(entry.modelVersion, "gemini-fixture")
        XCTAssertEqual(entry.originalDescription, "Paneer wrap with extra mint chutney")
        XCTAssertEqual(entry.thumbnailRelativePath, "ProtectedMealDrafts/original-input.jpg")

        let item = try XCTUnwrap(entry.items.first)
        XCTAssertEqual(item.identificationConfidence, 0.91)
        XCTAssertEqual(item.portionConfidence, 0.64)
    }

    func testAnalysisMetadataRoundTripsThroughSwiftData() throws {
        let schema = Schema([MealEntry.self, FoodItem.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let draft = makeDraft()
        let entryID = draft.id

        let writeContext = ModelContext(container)
        writeContext.insert(MealEntry(confirmedDraft: draft))
        try writeContext.save()

        let readContext = ModelContext(container)
        let entries = try readContext.fetch(FetchDescriptor<MealEntry>())
        let reloaded = try XCTUnwrap(entries.first(where: { $0.id == entryID }))
        let item = try XCTUnwrap(reloaded.items.first)

        XCTAssertEqual(reloaded.reviewReason, "Oil quantity was estimated.")
        XCTAssertEqual(reloaded.promptVersion, "vertex-meal-v1")
        XCTAssertEqual(reloaded.modelVersion, "gemini-fixture")
        XCTAssertEqual(reloaded.originalDescription, "Paneer wrap with extra mint chutney")
        XCTAssertEqual(reloaded.thumbnailRelativePath, "ProtectedMealDrafts/original-input.jpg")
        XCTAssertEqual(item.identificationConfidence, 0.91)
        XCTAssertEqual(item.portionConfidence, 0.64)
    }

    func testDuplicatePreservesAnalysisMetadataAndItemConfidence() throws {
        let original = MealEntry(confirmedDraft: makeDraft())

        let duplicate = original.duplicate(at: Date(timeIntervalSince1970: 1_800_000_000))

        XCTAssertEqual(duplicate.reviewReason, original.reviewReason)
        XCTAssertEqual(duplicate.promptVersion, original.promptVersion)
        XCTAssertEqual(duplicate.modelVersion, original.modelVersion)
        XCTAssertEqual(duplicate.originalDescription, original.originalDescription)
        XCTAssertEqual(duplicate.thumbnailRelativePath, original.thumbnailRelativePath)
        XCTAssertEqual(duplicate.analysisRoute, .personalMemory)

        let originalItem = try XCTUnwrap(original.items.first)
        let copiedItem = try XCTUnwrap(duplicate.items.first)
        XCTAssertNotEqual(copiedItem.id, originalItem.id)
        XCTAssertEqual(copiedItem.identificationConfidence, originalItem.identificationConfidence)
        XCTAssertEqual(copiedItem.portionConfidence, originalItem.portionConfidence)
    }

    private func makeDraft() -> AnalyzedMealDraft {
        AnalyzedMealDraft(
            id: UUID(),
            loggedAt: Date(timeIntervalSince1970: 1_750_000_000),
            title: "Paneer wrap",
            inputSource: .typedText,
            analysisRoute: .vertexFallback,
            items: [
                AnalyzedFoodItem(
                    name: "Paneer wrap",
                    quantity: 1,
                    unit: "wrap",
                    estimatedGrams: 220,
                    nutrition: NutritionValues(
                        caloriesKcal: 510,
                        proteinGrams: 22,
                        carbohydrateGrams: 48,
                        fatGrams: 26
                    ),
                    identificationConfidence: 0.91,
                    portionConfidence: 0.64,
                    assumptions: ["Oil quantity estimated"]
                )
            ],
            needsReview: true,
            reviewReason: "Oil quantity was estimated.",
            promptVersion: "vertex-meal-v1",
            modelVersion: "gemini-fixture",
            originalDescription: "Paneer wrap with extra mint chutney",
            protectedImagePath: "ProtectedMealDrafts/original-input.jpg"
        )
    }
}

private actor PersistenceProviderAnalyzer: DirectProviderAnalyzing {
    func analyze(_ request: MealAnalysisRequest) async throws -> AnalyzedMealDraft {
        AnalyzedMealDraft(
            id: request.id,
            loggedAt: request.loggedAt,
            title: "Fixture meal",
            inputSource: request.source,
            analysisRoute: .vertexFallback,
            items: [
                AnalyzedFoodItem(
                    name: "Fixture food",
                    nutrition: NutritionValues(caloriesKcal: 320)
                )
            ],
            reviewReason: "Fixture review",
            promptVersion: "fixture-v1",
            modelVersion: "fixture-model"
        )
    }
}
