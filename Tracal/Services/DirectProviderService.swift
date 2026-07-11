import Foundation

protocol DirectProviderAnalyzing: Sendable {
    func analyze(_ request: MealAnalysisRequest) async throws -> AnalyzedMealDraft
}

actor DirectProviderService: DirectProviderAnalyzing {
    private let credentialStore: any ProviderCredentialReading
    private let preferences: AIProviderPreferences
    private let usageRecorder: any AIUsageRecording
    private let transport: any ProviderHTTPTransport

    init(
        credentialStore: any ProviderCredentialReading = ProviderCredentialStore(),
        preferences: AIProviderPreferences = AIProviderPreferences(),
        usageRecorder: any AIUsageRecording = NoopAIUsageRecorder(),
        transport: any ProviderHTTPTransport = URLSessionProviderHTTPTransport()
    ) {
        self.credentialStore = credentialStore
        self.preferences = preferences
        self.usageRecorder = usageRecorder
        self.transport = transport
    }

    func analyze(_ request: MealAnalysisRequest) async throws -> AnalyzedMealDraft {
        try await analyze(
            request,
            provider: preferences.activeProvider,
            resultOnSuccess: .success
        )
    }

    func testConnection(provider: AIProvider) async throws {
        let request = MealAnalysisRequest(
            loggedAt: .now,
            source: .typedText,
            input: .text("One hard-boiled egg")
        )
        _ = try await analyze(request, provider: provider, resultOnSuccess: .connectionTest)
    }

    private func analyze(
        _ request: MealAnalysisRequest,
        provider: AIProvider,
        resultOnSuccess: AIUsageResult
    ) async throws -> AnalyzedMealDraft {
        guard preferences.hasConsent(for: provider) else {
            throw MealAnalysisError.providerConsentRequired(provider)
        }

        let credential: String
        do {
            credential = try credentialStore.credential(for: provider)
        } catch {
            throw MealAnalysisError.providerNotConfigured(provider)
        }
        let model = preferences.model(for: provider)
        let client = client(for: provider)

        for attempt in 1...2 {
            do {
                let response = try await client.analyze(
                    request,
                    model: model,
                    credential: credential,
                    attempt: attempt
                )
                await usageRecorder.record(
                    usageAttempt(
                        provider: provider,
                        model: model,
                        requestID: response.providerRequestID,
                        usage: response.usage,
                        result: resultOnSuccess,
                        attempt: attempt
                    )
                )
                return response.draft
            } catch is CancellationError {
                await usageRecorder.record(
                    usageAttempt(
                        provider: provider,
                        model: model,
                        result: .cancelled,
                        attempt: attempt
                    )
                )
                throw CancellationError()
            } catch let error as ProviderAnalysisError {
                let result: AIUsageResult = error.analysisError == .noFoodDetected
                    ? .noFood
                    : .invalidResponse
                await usageRecorder.record(
                    usageAttempt(
                        provider: provider,
                        model: model,
                        requestID: error.providerRequestID,
                        usage: error.usage,
                        result: result,
                        attempt: attempt
                    )
                )
                throw error.analysisError
            } catch let error as ProviderCallError {
                await usageRecorder.record(
                    usageAttempt(
                        provider: provider,
                        model: model,
                        requestID: error.providerRequestID,
                        usage: error.usage,
                        result: error.failure == .malformedResponse || error.failure == .truncated
                            ? .invalidResponse
                            : .providerFailure,
                        attempt: attempt
                    )
                )
                if error.failure == .truncated && attempt == 1 {
                    continue
                }
                throw MealAnalysisError.providerUnavailable(provider, error.failure)
            } catch {
                await usageRecorder.record(
                    usageAttempt(
                        provider: provider,
                        model: model,
                        result: .providerFailure,
                        attempt: attempt
                    )
                )
                throw MealAnalysisError.providerUnavailable(provider, .networkUnavailable)
            }
        }

        throw MealAnalysisError.providerUnavailable(provider, .malformedResponse)
    }

    private func client(for provider: AIProvider) -> any MealProviderClient {
        switch provider {
        case .openAI: OpenAIMealProviderClient(transport: transport)
        case .anthropic: AnthropicMealProviderClient(transport: transport)
        case .gemini: GeminiMealProviderClient(transport: transport)
        }
    }

    private func usageAttempt(
        provider: AIProvider,
        model: String,
        requestID: String? = nil,
        usage: ProviderUsage? = nil,
        result: AIUsageResult,
        attempt: Int
    ) -> AIUsageAttempt {
        AIUsageAttempt(
            provider: provider,
            model: model,
            providerRequestID: requestID,
            usage: usage,
            result: result,
            attemptNumber: attempt
        )
    }
}
