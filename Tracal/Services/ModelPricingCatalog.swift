import Foundation

struct ModelPricing: Hashable, Sendable {
    var provider: AIProvider
    var model: String
    var inputUSDPerMillion: Decimal
    var cachedInputUSDPerMillion: Decimal?
    var cacheWriteUSDPerMillion: Decimal?
    var outputUSDPerMillion: Decimal
    var effectiveDate: Date
}

struct ModelPricingCatalog: Sendable {
    static let current = ModelPricingCatalog(
        version: "2026-07-11",
        entries: [
            ModelPricing(
                provider: .openAI,
                model: "gpt-5.4-mini",
                inputUSDPerMillion: Decimal(string: "0.75")!,
                cachedInputUSDPerMillion: Decimal(string: "0.075")!,
                outputUSDPerMillion: Decimal(string: "4.50")!,
                effectiveDate: Self.date(2026, 7, 11)
            ),
            ModelPricing(
                provider: .anthropic,
                model: "claude-haiku-4-5-20251001",
                inputUSDPerMillion: Decimal(string: "1.00")!,
                cachedInputUSDPerMillion: Decimal(string: "0.10")!,
                cacheWriteUSDPerMillion: Decimal(string: "1.25")!,
                outputUSDPerMillion: Decimal(string: "5.00")!,
                effectiveDate: Self.date(2026, 7, 11)
            ),
            ModelPricing(
                provider: .gemini,
                model: "gemini-3.5-flash",
                inputUSDPerMillion: Decimal(string: "1.50")!,
                cachedInputUSDPerMillion: Decimal(string: "0.15")!,
                outputUSDPerMillion: Decimal(string: "9.00")!,
                effectiveDate: Self.date(2026, 7, 11)
            ),
        ]
    )

    var version: String
    private var entries: [ModelPricing]

    init(version: String, entries: [ModelPricing]) {
        self.version = version
        self.entries = entries
    }

    func pricing(for provider: AIProvider, model: String) -> ModelPricing? {
        entries.first { $0.provider == provider && $0.model == model }
    }

    var latestEffectiveDate: Date? {
        entries.map(\.effectiveDate).max()
    }

    func estimatedCostMicrodollars(
        provider: AIProvider,
        model: String,
        usage: ProviderUsage
    ) -> Int64? {
        guard let price = pricing(for: provider, model: model) else { return nil }
        guard
            usage.inputTokens != nil || usage.outputTokens != nil ||
            usage.cachedInputTokens != nil || usage.cacheWriteTokens != nil
        else {
            return nil
        }

        let input = max(0, usage.inputTokens ?? 0)
        let cached = max(0, usage.cachedInputTokens ?? 0)
        let cacheWrite = max(0, usage.cacheWriteTokens ?? 0)
        let regularInput: Int
        switch provider {
        case .anthropic:
            regularInput = input
        case .openAI, .gemini:
            regularInput = max(0, input - cached)
        }

        var microdollars = Decimal(regularInput) * price.inputUSDPerMillion
        microdollars += Decimal(cached) * (price.cachedInputUSDPerMillion ?? price.inputUSDPerMillion)
        microdollars += Decimal(cacheWrite) * (price.cacheWriteUSDPerMillion ?? price.inputUSDPerMillion)

        var output = max(0, usage.outputTokens ?? 0)
        if !usage.reasoningIncludedInOutput {
            output += max(0, usage.reasoningTokens ?? 0)
        }
        microdollars += Decimal(output) * price.outputUSDPerMillion

        var rounded = Decimal()
        NSDecimalRound(&rounded, &microdollars, 0, .plain)
        return NSDecimalNumber(decimal: rounded).int64Value
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar(identifier: .gregorian).date(
            from: DateComponents(timeZone: TimeZone(secondsFromGMT: 0), year: year, month: month, day: day)
        ) ?? .distantPast
    }
}
