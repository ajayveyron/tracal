import Foundation
import SwiftData

enum AIUsageResult: String, Codable, CaseIterable, Sendable {
    case success
    case noFood
    case invalidResponse
    case providerFailure
    case cancelled
    case connectionTest
}

struct ProviderUsage: Hashable, Sendable {
    var inputTokens: Int?
    var outputTokens: Int?
    var cachedInputTokens: Int?
    var cacheWriteTokens: Int?
    var reasoningTokens: Int?
    var totalTokens: Int?
    var reasoningIncludedInOutput: Bool

    init(
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        cachedInputTokens: Int? = nil,
        cacheWriteTokens: Int? = nil,
        reasoningTokens: Int? = nil,
        totalTokens: Int? = nil,
        reasoningIncludedInOutput: Bool = true
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cachedInputTokens = cachedInputTokens
        self.cacheWriteTokens = cacheWriteTokens
        self.reasoningTokens = reasoningTokens
        self.totalTokens = totalTokens
        self.reasoningIncludedInOutput = reasoningIncludedInOutput
    }

    var normalizedTotal: Int? {
        if let totalTokens { return max(0, totalTokens) }
        guard inputTokens != nil || outputTokens != nil || reasoningTokens != nil else { return nil }
        let reasoning = reasoningIncludedInOutput ? 0 : max(0, reasoningTokens ?? 0)
        return max(0, inputTokens ?? 0) + max(0, outputTokens ?? 0) + reasoning
    }
}

struct AIUsageAttempt: Sendable {
    var id = UUID()
    var createdAt = Date.now
    var provider: AIProvider
    var model: String
    var providerRequestID: String?
    var usage: ProviderUsage?
    var result: AIUsageResult
    var attemptNumber: Int
}

@Model
final class AIUsageRecord {
    @Attribute(.unique) var id: UUID
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

    init(attempt: AIUsageAttempt, catalog: ModelPricingCatalog = .current) {
        id = attempt.id
        createdAt = attempt.createdAt
        providerRawValue = attempt.provider.rawValue
        model = attempt.model
        providerRequestID = attempt.providerRequestID
        inputTokens = attempt.usage?.inputTokens
        outputTokens = attempt.usage?.outputTokens
        cachedInputTokens = attempt.usage?.cachedInputTokens
        cacheWriteTokens = attempt.usage?.cacheWriteTokens
        reasoningTokens = attempt.usage?.reasoningTokens
        totalTokens = attempt.usage?.normalizedTotal
        resultRawValue = attempt.result.rawValue
        attemptNumber = max(1, attempt.attemptNumber)
        estimatedCostMicrodollars = attempt.usage.flatMap {
            catalog.estimatedCostMicrodollars(provider: attempt.provider, model: attempt.model, usage: $0)
        }
        pricingCatalogVersion = catalog.version
        pricingEffectiveDate = catalog.pricing(for: attempt.provider, model: attempt.model)?.effectiveDate
    }

    init(snapshot: AIUsageSnapshot) {
        id = snapshot.id
        createdAt = snapshot.createdAt
        providerRawValue = snapshot.providerRawValue
        model = snapshot.model
        providerRequestID = snapshot.providerRequestID
        inputTokens = snapshot.inputTokens
        outputTokens = snapshot.outputTokens
        cachedInputTokens = snapshot.cachedInputTokens
        cacheWriteTokens = snapshot.cacheWriteTokens
        reasoningTokens = snapshot.reasoningTokens
        totalTokens = snapshot.totalTokens
        resultRawValue = snapshot.resultRawValue
        attemptNumber = snapshot.attemptNumber
        estimatedCostMicrodollars = snapshot.estimatedCostMicrodollars
        pricingCatalogVersion = snapshot.pricingCatalogVersion
        pricingEffectiveDate = snapshot.pricingEffectiveDate
    }

    var provider: AIProvider? {
        AIProvider(rawValue: providerRawValue)
    }

    var result: AIUsageResult {
        AIUsageResult(rawValue: resultRawValue) ?? .providerFailure
    }

    var estimatedCostUSD: Decimal? {
        estimatedCostMicrodollars.map { Decimal($0) / 1_000_000 }
    }
}

protocol AIUsageRecording: Sendable {
    func record(_ attempt: AIUsageAttempt) async
}

struct NoopAIUsageRecorder: AIUsageRecording {
    func record(_ attempt: AIUsageAttempt) async {}
}

actor SwiftDataAIUsageRecorder: AIUsageRecording {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func record(_ attempt: AIUsageAttempt) {
        let context = ModelContext(container)
        context.insert(AIUsageRecord(attempt: attempt))
        try? context.save()
    }
}
