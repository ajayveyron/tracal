import Foundation
import XCTest
@testable import Tracal

@MainActor
final class VertexGatewayClientTests: XCTestCase {
    func testGatewayMapsStructuredResponseAndRequestContract() async throws {
        let requestID = UUID()
        let responseData = Data(
            """
            {
              "schemaVersion": 1,
              "analysisId": "\(requestID.uuidString)",
              "title": "Samosas and chai",
              "items": [
                {
                  "name": "Samosa",
                  "amount": 2,
                  "unit": "piece",
                  "estimatedGrams": 180,
                  "caloriesKcal": 520,
                  "proteinG": 12,
                  "carbohydratesG": 58,
                  "fatG": 27,
                  "identificationConfidence": 0.96,
                  "portionConfidence": 0.72,
                  "assumptions": ["medium pieces"]
                }
              ],
              "needsReview": true,
              "reviewReason": "Confirm piece size",
              "promptVersion": "nutrition-v1",
              "modelVersion": "gateway-fixture"
            }
            """.utf8
        )
        let transport = RecordingGatewayTransport(responseData: responseData)
        let client = VertexGatewayClient(
            configuration: VertexGatewayConfiguration(
                baseURL: URL(string: "https://gateway.example.test")!
            ),
            authorizationProvider: FixtureGatewayAuthorizationProvider(),
            transport: transport
        )
        let request = MealAnalysisRequest(
            id: requestID,
            loggedAt: Date(timeIntervalSince1970: 1_750_000_000),
            source: .typedText,
            input: .text("two samosas and chai")
        )

        let draft = try await client.analyze(request)

        XCTAssertEqual(draft.id, requestID)
        XCTAssertEqual(draft.analysisRoute, .vertexFallback)
        XCTAssertEqual(draft.title, "Samosas and chai")
        XCTAssertEqual(draft.items.first?.quantity, 2)
        XCTAssertEqual(draft.totals.caloriesKcal, 520)
        XCTAssertEqual(draft.totals.carbohydrateGrams, 58)

        let capturedRequest = await transport.lastRequest()
        let sentRequest = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(sentRequest.url?.path, "/v1/analyze")
        XCTAssertEqual(sentRequest.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-token")
        XCTAssertEqual(sentRequest.value(forHTTPHeaderField: "Idempotency-Key"), requestID.uuidString)

        let body = try XCTUnwrap(sentRequest.httpBody)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        let input = try XCTUnwrap(json["input"] as? [String: Any])
        XCTAssertEqual(json["schemaVersion"] as? Int, 1)
        XCTAssertEqual(input["kind"] as? String, "text")
        XCTAssertEqual(input["text"] as? String, "two samosas and chai")
    }

    func testMissingConfigurationFailsWithoutTransportingMeal() async throws {
        let transport = RecordingGatewayTransport(responseData: Data())
        let client = VertexGatewayClient(
            configuration: nil,
            authorizationProvider: FixtureGatewayAuthorizationProvider(),
            transport: transport
        )

        do {
            _ = try await client.analyze(
                MealAnalysisRequest(
                    loggedAt: .now,
                    source: .typedText,
                    input: .text("dal and rice")
                )
            )
            XCTFail("Expected an unconfigured gateway error")
        } catch let error as MealAnalysisError {
            XCTAssertEqual(error, .gatewayUnavailable(.notConfigured))
        }

        let capturedRequest = await transport.lastRequest()
        XCTAssertNil(capturedRequest)
    }

    func testGatewayMapsNonFoodPhotoToActionableError() async throws {
        let transport = RecordingGatewayTransport(responseData: Data(), statusCode: 422)
        let client = VertexGatewayClient(
            configuration: VertexGatewayConfiguration(
                baseURL: URL(string: "https://gateway.example.test")!
            ),
            authorizationProvider: FixtureGatewayAuthorizationProvider(),
            transport: transport
        )

        do {
            _ = try await client.analyze(
                MealAnalysisRequest(
                    loggedAt: .now,
                    source: .cameraPhoto,
                    input: .photo(
                        SanitizedMealImage(
                            data: Data([0xFF, 0xD8, 0xFF]),
                            pixelWidth: 1,
                            pixelHeight: 1
                        ),
                        hint: nil
                    )
                )
            )
            XCTFail("Expected a non-food error")
        } catch let error as MealAnalysisError {
            XCTAssertEqual(error, .noFoodDetected)
            XCTAssertEqual(error.errorDescription, "No food or drink was found in that photo.")
        }
    }

    func testRuntimeConfigurationPrefersEnvironmentOverUserDefaults() throws {
        let suiteName = "VertexGatewayClientTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("https://user.example.test", forKey: VertexGatewayConfiguration.userDefaultsBaseURLKey)

        let configuration = try XCTUnwrap(
            VertexGatewayConfiguration.fromRuntime(
                environment: [
                    VertexGatewayConfiguration.runtimeBaseURLKey: "https://environment.example.test"
                ],
                userDefaults: defaults
            )
        )

        XCTAssertEqual(configuration.baseURL.host, "environment.example.test")
        XCTAssertEqual(configuration.analyzeURL.path, "/v1/analyze")
    }

    func testDebugRuntimeCanExplicitlyAllowLocalGateway() throws {
        let configuration = try XCTUnwrap(
            VertexGatewayConfiguration.fromRuntime(
                environment: [
                    VertexGatewayConfiguration.runtimeBaseURLKey: "http://127.0.0.1:8080",
                    VertexGatewayConfiguration.runtimeAllowsInsecureLocalhostKey: "true"
                ]
            )
        )

        #if DEBUG
        XCTAssertTrue(configuration.allowsInsecureLocalhost)
        #else
        XCTAssertFalse(configuration.allowsInsecureLocalhost)
        #endif
    }

    func testAutoProvisionSeedsEmptyURLAndTokenFromEnvironment() async throws {
        let suiteName = "GatewayAutoProvisionTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = "com.ajaypawriya.tracal.tests.auto-provision.\(UUID().uuidString)"
        let store = VertexGatewayTokenStore(service: service, account: "token")
        defer { try? store.delete() }

        let token = String(repeating: "a", count: 40)
        let changed = GatewayAutoProvision.applyIfNeeded(
            environment: [
                VertexGatewayConfiguration.runtimeBaseURLKey: "https://auto.example.test",
                GatewayAutoProvision.deviceTokenEnvironmentKey: token,
            ],
            userDefaults: defaults,
            tokenStore: store
        )

        XCTAssertTrue(changed)
        XCTAssertEqual(
            defaults.string(forKey: VertexGatewayConfiguration.userDefaultsBaseURLKey),
            "https://auto.example.test"
        )

        let provider = KeychainVertexGatewayAuthorizationProvider(service: service, account: "token")
        let auth = try await provider.authorization()
        XCTAssertEqual(auth.bearerToken, token)
    }

    func testDebugLocalGatewayDoesNotRequirePairedBearer() async throws {
        #if DEBUG
        let requestID = UUID()
        let responseData = Data(
            """
            {
              "schemaVersion": 1,
              "analysisId": "\(requestID.uuidString)",
              "title": "Local gateway meal",
              "items": [{
                "name": "Banana",
                "amount": 1,
                "unit": "piece",
                "caloriesKcal": 105,
                "proteinG": 1.3,
                "carbohydrateG": 27,
                "fatG": 0.4,
                "assumptions": []
              }],
              "needsReview": true
            }
            """.utf8
        )
        let transport = RecordingGatewayTransport(responseData: responseData)
        let client = VertexGatewayClient(
            configuration: VertexGatewayConfiguration(
                baseURL: URL(string: "http://127.0.0.1:8080")!,
                allowsInsecureLocalhost: true
            ),
            authorizationProvider: RejectingGatewayAuthorizationProvider(),
            transport: transport
        )

        let draft = try await client.analyze(
            MealAnalysisRequest(
                id: requestID,
                loggedAt: .now,
                source: .typedText,
                input: .text("a banana")
            )
        )

        XCTAssertEqual(draft.title, "Local gateway meal")
        let request = await transport.lastRequest()
        let capturedRequest = try XCTUnwrap(request)
        XCTAssertNil(capturedRequest.value(forHTTPHeaderField: "Authorization"))
        #endif
    }

    func testRouterUsesGatewayBeforeOnDeviceParsingForUnknownText() async throws {
        let gateway = SuccessfulGatewayAnalyzer()
        let router = DefaultMealAnalysisRouter(gateway: gateway)
        let request = MealAnalysisRequest(
            loggedAt: .now,
            source: .typedText,
            input: .text("two samosas and chai")
        )

        let draft = try await router.analyze(request)

        let gatewayCalls = await gateway.callCount()
        XCTAssertEqual(gatewayCalls, 1)
        XCTAssertEqual(draft.analysisRoute, .vertexFallback)
        XCTAssertEqual(draft.title, "Gateway meal")
    }

    func testRouterKeepsExplicitNutritionDeterministic() async throws {
        let gateway = SuccessfulGatewayAnalyzer()
        let router = DefaultMealAnalysisRouter(gateway: gateway)
        let request = MealAnalysisRequest(
            loggedAt: .now,
            source: .typedText,
            input: .text("Greek yogurt, 90 calories, 6g protein, 13g carbs, 2g fat")
        )

        let draft = try await router.analyze(request)

        let gatewayCalls = await gateway.callCount()
        XCTAssertEqual(gatewayCalls, 0)
        XCTAssertEqual(draft.analysisRoute, .deterministic)
        XCTAssertEqual(draft.totals.caloriesKcal, 90)
    }
}

private struct FixtureGatewayAuthorizationProvider: VertexGatewayAuthorizationProviding {
    func authorization() async throws -> VertexGatewayAuthorization {
        VertexGatewayAuthorization(bearerToken: "fixture-token")
    }
}

private struct RejectingGatewayAuthorizationProvider: VertexGatewayAuthorizationProviding {
    func authorization() async throws -> VertexGatewayAuthorization {
        throw KeychainGatewayAuthorizationError.missingToken
    }
}

private actor RecordingGatewayTransport: VertexGatewayTransport {
    private let responseData: Data
    private let statusCode: Int
    private var capturedRequest: URLRequest?

    init(responseData: Data, statusCode: Int = 200) {
        self.responseData = responseData
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        capturedRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (responseData, response)
    }

    func lastRequest() -> URLRequest? {
        capturedRequest
    }
}

private actor SuccessfulGatewayAnalyzer: VertexGatewayAnalyzing {
    private var calls = 0

    func analyze(_ request: MealAnalysisRequest) async throws -> AnalyzedMealDraft {
        calls += 1
        return AnalyzedMealDraft(
            id: request.id,
            loggedAt: request.loggedAt,
            title: "Gateway meal",
            inputSource: request.source,
            analysisRoute: .vertexFallback,
            items: [
                AnalyzedFoodItem(
                    name: "Samosas and chai",
                    nutrition: NutritionValues(caloriesKcal: 640)
                )
            ]
        )
    }

    func callCount() -> Int {
        calls
    }
}
