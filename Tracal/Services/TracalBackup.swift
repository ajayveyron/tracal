import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let tracalBackup = UTType(
        exportedAs: "com.ajaypawriya.tracal.backup",
        conformingTo: .json
    )
}

struct TracalBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.tracalBackup, .json] }
    static var writableContentTypes: [UTType] { [.tracalBackup] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct AIUsageSnapshot: Codable, Sendable {
    var id: UUID
    var createdAt: Date
    var providerRawValue: String
    var model: String
    var providerRequestID: String?
    var inputTokens: Int?
    var outputTokens: Int?
    var cachedInputTokens: Int?
    var cacheWriteTokens: Int?
    var reasoningTokens: Int?
    var totalTokens: Int?
    var resultRawValue: String
    var attemptNumber: Int
    var estimatedCostMicrodollars: Int64?
    var pricingCatalogVersion: String
    var pricingEffectiveDate: Date?

    init(_ record: AIUsageRecord) {
        id = record.id
        createdAt = record.createdAt
        providerRawValue = record.providerRawValue
        model = record.model
        providerRequestID = record.providerRequestID
        inputTokens = record.inputTokens
        outputTokens = record.outputTokens
        cachedInputTokens = record.cachedInputTokens
        cacheWriteTokens = record.cacheWriteTokens
        reasoningTokens = record.reasoningTokens
        totalTokens = record.totalTokens
        resultRawValue = record.resultRawValue
        attemptNumber = record.attemptNumber
        estimatedCostMicrodollars = record.estimatedCostMicrodollars
        pricingCatalogVersion = record.pricingCatalogVersion
        pricingEffectiveDate = record.pricingEffectiveDate
    }
}

private struct TracalBackupPayload: Codable, Sendable {
    var schemaVersion: Int
    var exportedAt: Date
    var goals: [GoalSnapshot]
    var meals: [MealSnapshot]
    var usage: [AIUsageSnapshot]
}

private struct GoalSnapshot: Codable, Sendable {
    var id: UUID
    var effectiveDate: Date
    var calorieTarget: Double
    var proteinTargetG: Double?
    var carbohydrateTargetG: Double?
    var fatTargetG: Double?
    var createdAt: Date
}

private struct MealSnapshot: Codable, Sendable {
    var id: UUID
    var loggedAt: Date
    var inputSourceRawValue: String
    var analysisRouteRawValue: String
    var stateRawValue: String
    var title: String
    var caloriesKcal: Double
    var proteinG: Double
    var carbohydrateG: Double
    var fatG: Double
    var confidence: Double?
    var reviewReason: String?
    var promptVersion: String?
    var modelVersion: String?
    var originalDescription: String?
    var createdAt: Date
    var updatedAt: Date
    var imageBase64: String?
    var items: [FoodSnapshot]
}

private struct FoodSnapshot: Codable, Sendable {
    var id: UUID
    var name: String
    var amount: Double
    var unit: String
    var estimatedGrams: Double?
    var caloriesKcal: Double
    var proteinG: Double
    var carbohydrateG: Double
    var fatG: Double
    var identificationConfidence: Double?
    var portionConfidence: Double?
    var assumptions: [String]
    var wasCorrected: Bool
}

@MainActor
struct TracalBackupService {
    private let context: ModelContext
    private let imageStore: ProtectedMealImageStore

    init(context: ModelContext, imageStore: ProtectedMealImageStore = ProtectedMealImageStore()) {
        self.context = context
        self.imageStore = imageStore
    }

    func exportDocument() async throws -> TracalBackupDocument {
        let goals = try context.fetch(FetchDescriptor<DailyGoal>())
        let meals = try context.fetch(FetchDescriptor<MealEntry>())
        let usage = try context.fetch(FetchDescriptor<AIUsageRecord>())

        var mealSnapshots: [MealSnapshot] = []
        for meal in meals {
            let image = await imageStore.data(path: meal.thumbnailRelativePath)
            mealSnapshots.append(
                MealSnapshot(
                    id: meal.id,
                    loggedAt: meal.loggedAt,
                    inputSourceRawValue: meal.inputSourceRawValue,
                    analysisRouteRawValue: meal.analysisRouteRawValue,
                    stateRawValue: meal.stateRawValue,
                    title: meal.title,
                    caloriesKcal: meal.caloriesKcal,
                    proteinG: meal.proteinG,
                    carbohydrateG: meal.carbohydrateG,
                    fatG: meal.fatG,
                    confidence: meal.confidence,
                    reviewReason: meal.reviewReason,
                    promptVersion: meal.promptVersion,
                    modelVersion: meal.modelVersion,
                    originalDescription: meal.originalDescription,
                    createdAt: meal.createdAt,
                    updatedAt: meal.updatedAt,
                    imageBase64: image?.base64EncodedString(),
                    items: meal.items.map {
                        FoodSnapshot(
                            id: $0.id,
                            name: $0.name,
                            amount: $0.amount,
                            unit: $0.unit,
                            estimatedGrams: $0.estimatedGrams,
                            caloriesKcal: $0.caloriesKcal,
                            proteinG: $0.proteinG,
                            carbohydrateG: $0.carbohydrateG,
                            fatG: $0.fatG,
                            identificationConfidence: $0.identificationConfidence,
                            portionConfidence: $0.portionConfidence,
                            assumptions: $0.assumptions,
                            wasCorrected: $0.wasCorrected
                        )
                    }
                )
            )
        }

        let payload = TracalBackupPayload(
            schemaVersion: 1,
            exportedAt: .now,
            goals: goals.map {
                GoalSnapshot(
                    id: $0.id,
                    effectiveDate: $0.effectiveDate,
                    calorieTarget: $0.calorieTarget,
                    proteinTargetG: $0.proteinTargetG,
                    carbohydrateTargetG: $0.carbohydrateTargetG,
                    fatTargetG: $0.fatTargetG,
                    createdAt: $0.createdAt
                )
            },
            meals: mealSnapshots,
            usage: usage.map(AIUsageSnapshot.init)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return TracalBackupDocument(data: try encoder.encode(payload))
    }

    func importDocument(_ data: Data) async throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(TracalBackupPayload.self, from: data)
        guard payload.schemaVersion == 1 else { throw CocoaError(.fileReadUnsupportedScheme) }

        let existingGoalIDs = Set(try context.fetch(FetchDescriptor<DailyGoal>()).map(\.id))
        let existingMealIDs = Set(try context.fetch(FetchDescriptor<MealEntry>()).map(\.id))
        let existingUsageIDs = Set(try context.fetch(FetchDescriptor<AIUsageRecord>()).map(\.id))

        for goal in payload.goals where !existingGoalIDs.contains(goal.id) {
            context.insert(
                DailyGoal(
                    id: goal.id,
                    effectiveDate: goal.effectiveDate,
                    calorieTarget: goal.calorieTarget,
                    proteinTargetG: goal.proteinTargetG,
                    carbohydrateTargetG: goal.carbohydrateTargetG,
                    fatTargetG: goal.fatTargetG,
                    createdAt: goal.createdAt
                )
            )
        }

        for meal in payload.meals where !existingMealIDs.contains(meal.id) {
            let imagePath: String?
            if let encoded = meal.imageBase64, let image = Data(base64Encoded: encoded) {
                imagePath = try await imageStore.restore(image, id: meal.id)
            } else {
                imagePath = nil
            }
            let items = meal.items.map {
                FoodItem(
                    id: $0.id,
                    name: $0.name,
                    amount: $0.amount,
                    unit: $0.unit,
                    estimatedGrams: $0.estimatedGrams,
                    caloriesKcal: $0.caloriesKcal,
                    proteinG: $0.proteinG,
                    carbohydrateG: $0.carbohydrateG,
                    fatG: $0.fatG,
                    identificationConfidence: $0.identificationConfidence,
                    portionConfidence: $0.portionConfidence,
                    assumptions: $0.assumptions,
                    wasCorrected: $0.wasCorrected
                )
            }
            context.insert(
                MealEntry(
                    id: meal.id,
                    loggedAt: meal.loggedAt,
                    inputSource: StoredMealInputSource(rawValue: meal.inputSourceRawValue) ?? .manual,
                    analysisRoute: StoredMealAnalysisRoute(rawValue: meal.analysisRouteRawValue) ?? .manual,
                    state: StoredMealEntryState(rawValue: meal.stateRawValue) ?? .confirmed,
                    title: meal.title,
                    caloriesKcal: meal.caloriesKcal,
                    proteinG: meal.proteinG,
                    carbohydrateG: meal.carbohydrateG,
                    fatG: meal.fatG,
                    confidence: meal.confidence,
                    thumbnailRelativePath: imagePath,
                    reviewReason: meal.reviewReason,
                    promptVersion: meal.promptVersion,
                    modelVersion: meal.modelVersion,
                    originalDescription: meal.originalDescription,
                    createdAt: meal.createdAt,
                    updatedAt: meal.updatedAt,
                    items: items
                )
            )
        }

        for usage in payload.usage where !existingUsageIDs.contains(usage.id) {
            context.insert(AIUsageRecord(snapshot: usage))
        }
        try context.save()
    }
}
