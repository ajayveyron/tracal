import Foundation
import XCTest
@testable import Tracal

final class DirectProviderClientTests: XCTestCase {
    func testOpenAIUsesOfficialResponsesAPIAndNormalizesUsage() async throws {
        let payload = try mealPayloadData()
        let body: [String: Any] = [
            "id": "resp_fixture",
            "status": "completed",
            "output": [[
                "content": [[
                    "type": "output_text",
                    "text": String(decoding: payload, as: UTF8.self),
                ]],
            ]],
            "usage": [
                "input_tokens": 1_000,
                "output_tokens": 100,
                "total_tokens": 1_100,
                "input_tokens_details": ["cached_tokens": 200],
                "output_tokens_details": ["reasoning_tokens": 25],
            ],
        ]
        let transport = ProviderTransportFixture(data: try json(body))

        let response = try await OpenAIMealProviderClient(transport: transport).analyze(
            request,
            model: AIProvider.openAI.defaultModel,
            credential: "test-key-never-sent",
            attempt: 1
        )

        let storedRequest = await transport.capturedRequest()
        let captured = try XCTUnwrap(storedRequest)
        XCTAssertEqual(captured.url?.absoluteString, "https://api.openai.com/v1/responses")
        XCTAssertEqual(captured.value(forHTTPHeaderField: "Authorization"), "Bearer test-key-never-sent")
        XCTAssertEqual(response.providerRequestID, "resp_fixture")
        XCTAssertEqual(response.usage?.inputTokens, 1_000)
        XCTAssertEqual(response.usage?.cachedInputTokens, 200)
        XCTAssertEqual(response.usage?.reasoningTokens, 25)
        XCTAssertEqual(response.draft.analysisRoute, .openAI)
    }

    func testAnthropicUsesOfficialMessagesAPIAndNormalizesCacheUsage() async throws {
        let body: [String: Any] = [
            "id": "msg_fixture",
            "stop_reason": "tool_use",
            "content": [[
                "type": "tool_use",
                "name": "record_meal_analysis",
                "input": mealPayloadObject(),
            ]],
            "usage": [
                "input_tokens": 1_000,
                "output_tokens": 100,
                "cache_read_input_tokens": 200,
                "cache_creation_input_tokens": 50,
            ],
        ]
        let transport = ProviderTransportFixture(data: try json(body))

        let response = try await AnthropicMealProviderClient(transport: transport).analyze(
            request,
            model: AIProvider.anthropic.defaultModel,
            credential: "test-key-never-sent",
            attempt: 1
        )

        let storedRequest = await transport.capturedRequest()
        let captured = try XCTUnwrap(storedRequest)
        XCTAssertEqual(captured.url?.absoluteString, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(captured.value(forHTTPHeaderField: "x-api-key"), "test-key-never-sent")
        XCTAssertEqual(captured.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertEqual(response.usage?.cachedInputTokens, 200)
        XCTAssertEqual(response.usage?.cacheWriteTokens, 50)
        XCTAssertEqual(response.usage?.totalTokens, 1_350)
        XCTAssertEqual(response.draft.analysisRoute, .anthropic)
    }

    func testGeminiUsesOfficialGenerateContentAPIAndNormalizesThoughtTokens() async throws {
        let payload = try mealPayloadData()
        let body: [String: Any] = [
            "candidates": [[
                "finishReason": "STOP",
                "content": [
                    "parts": [["text": String(decoding: payload, as: UTF8.self)]],
                ],
            ]],
            "usageMetadata": [
                "promptTokenCount": 1_000,
                "candidatesTokenCount": 100,
                "cachedContentTokenCount": 200,
                "thoughtsTokenCount": 25,
                "totalTokenCount": 1_125,
            ],
        ]
        let transport = ProviderTransportFixture(data: try json(body))

        let response = try await GeminiMealProviderClient(transport: transport).analyze(
            request,
            model: AIProvider.gemini.defaultModel,
            credential: "test-key-never-sent",
            attempt: 1
        )

        let storedRequest = await transport.capturedRequest()
        let captured = try XCTUnwrap(storedRequest)
        XCTAssertEqual(
            captured.url?.absoluteString,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent"
        )
        XCTAssertEqual(captured.value(forHTTPHeaderField: "x-goog-api-key"), "test-key-never-sent")
        XCTAssertEqual(response.usage?.cachedInputTokens, 200)
        XCTAssertEqual(response.usage?.reasoningTokens, 25)
        XCTAssertEqual(response.usage?.totalTokens, 1_125)
        XCTAssertEqual(response.draft.analysisRoute, .gemini)
    }

    func testInvalidAndTruncatedResponsesNeverProduceDrafts() async throws {
        let noFood = try mealPayloadData(containsFood: false)
        let openAI = ProviderTransportFixture(data: try json([
            "id": "resp_no_food",
            "status": "completed",
            "output": [["content": [["type": "output_text", "text": String(decoding: noFood, as: UTF8.self)]]]],
        ]))

        do {
            _ = try await OpenAIMealProviderClient(transport: openAI).analyze(
                request,
                model: AIProvider.openAI.defaultModel,
                credential: "test-key-never-sent",
                attempt: 1
            )
            XCTFail("A non-food response must not produce a draft.")
        } catch let error as ProviderAnalysisError {
            XCTAssertEqual(error.analysisError, .noFoodDetected)
        }

        let truncated = ProviderTransportFixture(data: try json([
            "id": "resp_truncated",
            "status": "incomplete",
            "incomplete_details": ["reason": "max_output_tokens"],
            "output": [],
        ]))
        do {
            _ = try await OpenAIMealProviderClient(transport: truncated).analyze(
                request,
                model: AIProvider.openAI.defaultModel,
                credential: "test-key-never-sent",
                attempt: 1
            )
            XCTFail("A truncated response must not produce a draft.")
        } catch let error as ProviderCallError {
            XCTAssertEqual(error.failure, .truncated)
        }
    }

    private var request: MealAnalysisRequest {
        MealAnalysisRequest(
            loggedAt: Date(timeIntervalSince1970: 1_750_000_000),
            source: .typedText,
            input: .text("One egg and toast")
        )
    }

    private func mealPayloadData(containsFood: Bool = true) throws -> Data {
        try json(mealPayloadObject(containsFood: containsFood))
    }

    private func mealPayloadObject(containsFood: Bool = true) -> [String: Any] {
        [
            "containsFoodOrDrink": containsFood,
            "title": containsFood ? "Egg and toast" : "Not food",
            "reviewReason": containsFood ? "Portion estimated." : "",
            "items": containsFood ? [[
                "name": "Egg and toast",
                "quantity": 1.0,
                "unit": "meal",
                "estimatedGrams": 150.0,
                "nutrition": [
                    "caloriesKcal": 260.0,
                    "proteinGrams": 13.0,
                    "carbohydrateGrams": 25.0,
                    "fatGrams": 12.0,
                ],
                "identificationConfidence": 0.9,
                "portionConfidence": 0.8,
                "assumptions": ["One slice of toast"],
            ]] : [],
        ]
    }

    private func json(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}

final class ModelPricingCatalogTests: XCTestCase {
    func testVersionedPricingSeparatesRegularCachedAndReasoningTokens() {
        let openAI = ProviderUsage(
            inputTokens: 1_000,
            outputTokens: 100,
            cachedInputTokens: 200,
            reasoningTokens: 25,
            reasoningIncludedInOutput: true
        )
        XCTAssertEqual(
            ModelPricingCatalog.current.estimatedCostMicrodollars(
                provider: .openAI,
                model: AIProvider.openAI.defaultModel,
                usage: openAI
            ),
            1_065
        )

        let gemini = ProviderUsage(
            inputTokens: 1_000,
            outputTokens: 100,
            cachedInputTokens: 200,
            reasoningTokens: 20,
            reasoningIncludedInOutput: false
        )
        XCTAssertEqual(
            ModelPricingCatalog.current.estimatedCostMicrodollars(
                provider: .gemini,
                model: AIProvider.gemini.defaultModel,
                usage: gemini
            ),
            2_310
        )
    }

    func testUnknownModelOrMissingUsageProducesUnknownCost() {
        XCTAssertNil(
            ModelPricingCatalog.current.estimatedCostMicrodollars(
                provider: .openAI,
                model: "future-model",
                usage: ProviderUsage(inputTokens: 100)
            )
        )
        XCTAssertNil(
            ModelPricingCatalog.current.estimatedCostMicrodollars(
                provider: .openAI,
                model: AIProvider.openAI.defaultModel,
                usage: ProviderUsage()
            )
        )
    }
}

final class DirectProviderServiceTests: XCTestCase {
    func testTruncatedRetryIsRecordedAsSeparateBillableAttempt() async throws {
        let suiteName = "DirectProviderServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = AIProviderPreferences(defaults: defaults)
        preferences.activeProvider = .openAI
        preferences.setConsent(true, for: .openAI)

        let payload = try JSONSerialization.data(
            withJSONObject: retryMealPayload,
            options: [.sortedKeys]
        )
        let first = try JSONSerialization.data(withJSONObject: [
            "id": "resp_first",
            "status": "incomplete",
            "incomplete_details": ["reason": "max_output_tokens"],
            "output": [],
            "usage": ["input_tokens": 80, "output_tokens": 20, "total_tokens": 100],
        ])
        let second = try JSONSerialization.data(withJSONObject: [
            "id": "resp_second",
            "status": "completed",
            "output": [["content": [[
                "type": "output_text",
                "text": String(decoding: payload, as: UTF8.self),
            ]]]],
            "usage": ["input_tokens": 60, "output_tokens": 40, "total_tokens": 100],
        ])
        let transport = ProviderTransportFixture(responses: [first, second])
        let recorder = UsageRecorderFixture()
        let service = DirectProviderService(
            credentialStore: CredentialReaderFixture(),
            preferences: preferences,
            usageRecorder: recorder,
            transport: transport
        )

        _ = try await service.analyze(
            MealAnalysisRequest(
                loggedAt: .now,
                source: .typedText,
                input: .text("One egg and toast")
            )
        )

        let attempts = await recorder.recordedAttempts()
        XCTAssertEqual(attempts.map(\.attemptNumber), [1, 2])
        XCTAssertEqual(attempts.map(\.result), [.invalidResponse, .success])
        XCTAssertEqual(attempts.map { $0.usage?.totalTokens }, [100, 100])
        let requestCount = await transport.requestCount()
        XCTAssertEqual(requestCount, 2)
    }

    private var retryMealPayload: [String: Any] {
        [
            "containsFoodOrDrink": true,
            "title": "Egg and toast",
            "reviewReason": "Portion estimated.",
            "items": [[
                "name": "Egg and toast",
                "quantity": 1.0,
                "unit": "meal",
                "estimatedGrams": 150.0,
                "nutrition": [
                    "caloriesKcal": 260.0,
                    "proteinGrams": 13.0,
                    "carbohydrateGrams": 25.0,
                    "fatGrams": 12.0,
                ],
                "identificationConfidence": 0.9,
                "portionConfidence": 0.8,
                "assumptions": ["One slice of toast"],
            ]],
        ]
    }
}

private actor ProviderTransportFixture: ProviderHTTPTransport {
    private var responses: [Data]
    private var request: URLRequest?
    private var requests = 0

    init(data: Data) {
        responses = [data]
    }

    init(responses: [Data]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        self.request = request
        requests += 1
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        guard !responses.isEmpty else {
            throw ProviderCallError(failure: .networkUnavailable)
        }
        return (responses.removeFirst(), response)
    }

    func capturedRequest() -> URLRequest? {
        request
    }

    func requestCount() -> Int {
        requests
    }
}

private struct CredentialReaderFixture: ProviderCredentialReading {
    func credential(for provider: AIProvider) throws -> String {
        "test-key-never-sent"
    }
}

private actor UsageRecorderFixture: AIUsageRecording {
    private var attempts: [AIUsageAttempt] = []

    func record(_ attempt: AIUsageAttempt) {
        attempts.append(attempt)
    }

    func recordedAttempts() -> [AIUsageAttempt] {
        attempts
    }
}
