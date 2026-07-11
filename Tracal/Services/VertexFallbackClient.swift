import Foundation
import Security

public struct VertexGatewayConfiguration: Hashable, Sendable {
    public static let runtimeBaseURLKey = "TRACAL_GATEWAY_BASE_URL"
    public static let runtimeAllowsInsecureLocalhostKey = "TRACAL_ALLOW_INSECURE_LOCAL"
    public static let userDefaultsBaseURLKey = "vertexGatewayURL"

    public var baseURL: URL
    public var timeout: TimeInterval
    public var maximumRequestBytes: Int
    public var maximumResponseBytes: Int
    public var allowsInsecureLocalhost: Bool

    public init(
        baseURL: URL,
        timeout: TimeInterval = 45,
        maximumRequestBytes: Int = 6_000_000,
        maximumResponseBytes: Int = 1_000_000,
        allowsInsecureLocalhost: Bool = false
    ) {
        self.baseURL = baseURL
        self.timeout = max(5, timeout)
        self.maximumRequestBytes = max(1_024, maximumRequestBytes)
        self.maximumResponseBytes = max(1_024, maximumResponseBytes)
        self.allowsInsecureLocalhost = allowsInsecureLocalhost
    }

    public var analyzeURL: URL {
        if baseURL.path.hasSuffix("/v1/analyze") {
            return baseURL
        }
        return baseURL.appending(path: "v1/analyze")
    }

    public static func fromRuntime(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        userDefaults: UserDefaults = .standard
    ) -> VertexGatewayConfiguration? {
        let environmentValue = environment[runtimeBaseURLKey]
            ?? environment["TRACAL_GATEWAY_URL"]
        let userValue = userDefaults.string(forKey: userDefaultsBaseURLKey)
        let bundleValue = bundle.object(forInfoDictionaryKey: runtimeBaseURLKey) as? String
            ?? bundle.object(forInfoDictionaryKey: "TRACAL_GATEWAY_URL") as? String
        guard let rawValue = (environmentValue ?? userValue ?? bundleValue)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !rawValue.isEmpty,
            !rawValue.contains("$("),
            let url = URL(string: rawValue)
        else {
            return nil
        }
        #if DEBUG
        let insecureLocalValue = environment[runtimeAllowsInsecureLocalhostKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let allowsInsecureLocalhost = insecureLocalValue.map {
            ["1", "true", "yes"].contains($0)
        } ?? false
        #else
        let allowsInsecureLocalhost = false
        #endif

        return VertexGatewayConfiguration(
            baseURL: url,
            allowsInsecureLocalhost: allowsInsecureLocalhost
        )
    }
}

public struct VertexGatewayAuthorization: Hashable, Sendable {
    public var bearerToken: String

    public init(bearerToken: String) {
        self.bearerToken = bearerToken
    }
}

public protocol VertexGatewayAuthorizationProviding: Sendable {
    func authorization() async throws -> VertexGatewayAuthorization
}

public enum KeychainGatewayAuthorizationError: Error, Hashable, Sendable {
    case missingToken
    case unreadableToken
    case keychainFailure(OSStatus)
}

/// Reads the gateway bearer from the device-only Keychain after the app's
/// biometric gate has succeeded. The token is never present in source, bundle
/// resources, UserDefaults, request logs, or error text.
public struct KeychainVertexGatewayAuthorizationProvider: VertexGatewayAuthorizationProviding {
    public static let defaultService = "com.ajaypawriya.tracal.vertex-gateway"
    public static let defaultAccount = "bearer-token-v1"

    public var service: String
    public var account: String

    public init(
        service: String = Self.defaultService,
        account: String = Self.defaultAccount
    ) {
        self.service = service
        self.account = account
    }

    public func authorization() async throws -> VertexGatewayAuthorization {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status != errSecItemNotFound else {
            throw KeychainGatewayAuthorizationError.missingToken
        }
        guard status == errSecSuccess else {
            throw KeychainGatewayAuthorizationError.keychainFailure(status)
        }
        guard
            let data = result as? Data,
            let token = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !token.isEmpty
        else {
            throw KeychainGatewayAuthorizationError.unreadableToken
        }
        return VertexGatewayAuthorization(bearerToken: token)
    }
}

/// Used by the sign-in/provisioning layer to install or revoke the bearer. It
/// stores a device-only value and deliberately exposes no read API.
public struct VertexGatewayTokenStore: Sendable {
    public var service: String
    public var account: String

    public init(
        service: String = KeychainVertexGatewayAuthorizationProvider.defaultService,
        account: String = KeychainVertexGatewayAuthorizationProvider.defaultAccount
    ) {
        self.service = service
        self.account = account
    }

    public func store(_ token: String) throws {
        let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = token.data(using: .utf8), !data.isEmpty else {
            throw KeychainGatewayAuthorizationError.unreadableToken
        }

        let identity: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(identity as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainGatewayAuthorizationError.keychainFailure(updateStatus)
        }

        var insertion = identity
        insertion.merge(attributes) { _, new in new }
        let insertionStatus = SecItemAdd(insertion as CFDictionary, nil)
        guard insertionStatus == errSecSuccess else {
            throw KeychainGatewayAuthorizationError.keychainFailure(insertionStatus)
        }
    }

    public func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainGatewayAuthorizationError.keychainFailure(status)
        }
    }
}

public protocol VertexGatewayTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionVertexGatewayTransport: VertexGatewayTransport {
    private let session: URLSession

    public init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.httpCookieStorage = nil
            configuration.httpShouldSetCookies = false
            configuration.waitsForConnectivity = false
            self.session = URLSession(configuration: configuration)
        }
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, response)
    }
}

public protocol VertexGatewayAnalyzing: Sendable {
    func analyze(_ request: MealAnalysisRequest) async throws -> AnalyzedMealDraft
}

/// Talks only to the private gateway. Vertex service credentials remain on the
/// gateway; this client sends a short-lived bearer loaded from Keychain.
public actor VertexGatewayClient: VertexGatewayAnalyzing {
    private let configuration: VertexGatewayConfiguration?
    private let authorizationProvider: any VertexGatewayAuthorizationProviding
    private let transport: any VertexGatewayTransport
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        configuration: VertexGatewayConfiguration? = .fromRuntime(),
        authorizationProvider: any VertexGatewayAuthorizationProviding = KeychainVertexGatewayAuthorizationProvider(),
        transport: any VertexGatewayTransport = URLSessionVertexGatewayTransport()
    ) {
        self.configuration = configuration
        self.authorizationProvider = authorizationProvider
        self.transport = transport

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func analyze(_ request: MealAnalysisRequest) async throws -> AnalyzedMealDraft {
        guard let configuration else {
            throw MealAnalysisError.gatewayUnavailable(.notConfigured)
        }
        guard Self.isValid(configuration) else {
            throw MealAnalysisError.gatewayUnavailable(.invalidEndpoint)
        }

        let authorization: VertexGatewayAuthorization?
        if configuration.allowsInsecureLocalhost {
            authorization = nil
        } else {
            do {
                authorization = try await authorizationProvider.authorization()
            } catch is CancellationError {
                throw MealAnalysisError.cancelled
            } catch {
                throw MealAnalysisError.gatewayUnavailable(.authorizationUnavailable)
            }
        }

        let payload = VertexGatewayAnalysisRequest(request: request)
        let body: Data
        do {
            body = try encoder.encode(payload)
        } catch {
            throw MealAnalysisError.invalidModelResponse("Gateway request encoding failed")
        }
        guard body.count <= configuration.maximumRequestBytes else {
            throw MealAnalysisError.gatewayUnavailable(.requestTooLarge)
        }

        var urlRequest = URLRequest(
            url: configuration.analyzeURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: configuration.timeout
        )
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = body
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        if let authorization {
            urlRequest.setValue(
                "Bearer \(authorization.bearerToken)",
                forHTTPHeaderField: "Authorization"
            )
        }
        urlRequest.setValue(request.id.uuidString, forHTTPHeaderField: "Idempotency-Key")
        urlRequest.setValue("1", forHTTPHeaderField: "X-Tracal-Schema-Version")

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.data(for: urlRequest)
        } catch is CancellationError {
            throw MealAnalysisError.cancelled
        } catch {
            throw MealAnalysisError.gatewayUnavailable(.networkUnavailable)
        }

        guard (200..<300).contains(response.statusCode) else {
            if response.statusCode == 422 {
                throw MealAnalysisError.noFoodDetected
            }
            throw MealAnalysisError.gatewayUnavailable(.rejected(statusCode: response.statusCode))
        }
        guard data.count <= configuration.maximumResponseBytes else {
            throw MealAnalysisError.gatewayUnavailable(.responseTooLarge)
        }

        let result: VertexGatewayAnalysisResponse
        do {
            result = try decoder.decode(VertexGatewayAnalysisResponse.self, from: data)
        } catch {
            throw MealAnalysisError.gatewayUnavailable(.malformedResponse)
        }
        guard result.schemaVersion == 1, result.analysisId == request.id else {
            throw MealAnalysisError.gatewayUnavailable(.malformedResponse)
        }

        return try result.makeDraft(for: request)
    }

    private static func isValid(_ configuration: VertexGatewayConfiguration) -> Bool {
        let url = configuration.analyzeURL
        guard url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else {
            return false
        }
        if url.scheme?.lowercased() == "https" {
            return url.host != nil
        }
        #if !DEBUG
        return false
        #else
        guard configuration.allowsInsecureLocalhost, url.scheme?.lowercased() == "http" else {
            return false
        }
        return ["localhost", "127.0.0.1", "::1"].contains(url.host?.lowercased() ?? "")
        #endif
    }
}

@available(*, deprecated, renamed: "VertexGatewayClient")
public typealias VertexFallbackClient = VertexGatewayClient

struct VertexGatewayAnalysisRequest: Encodable, Sendable {
    struct Input: Encodable, Sendable {
        struct Image: Encodable, Sendable {
            var bytesBase64: Data
            var mimeType: String
            var pixelWidth: Int
            var pixelHeight: Int
        }

        var kind: String
        var text: String?
        var hint: String?
        var image: Image?
    }

    var schemaVersion = 1
    var analysisId: UUID
    var source: String
    var loggedAt: Date
    var input: Input

    init(request: MealAnalysisRequest) {
        analysisId = request.id
        source = request.source.rawValue
        loggedAt = request.loggedAt
        switch request.input {
        case .text(let text):
            input = Input(kind: "text", text: text, hint: nil, image: nil)
        case .photo(let image, let hint):
            input = Input(
                kind: "photo",
                text: nil,
                hint: hint,
                image: Input.Image(
                    bytesBase64: image.data,
                    mimeType: image.mimeType,
                    pixelWidth: image.pixelWidth,
                    pixelHeight: image.pixelHeight
                )
            )
        }
    }
}

struct VertexGatewayAnalysisResponse: Decodable, Sendable {
    struct Item: Decodable, Sendable {
        var id: UUID?
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

        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case amount
            case quantity
            case unit
            case estimatedGrams
            case caloriesKcal
            case proteinG
            case carbohydrateG
            case carbohydratesG
            case fatG
            case identificationConfidence
            case portionConfidence
            case assumptions
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            id = try values.decodeIfPresent(UUID.self, forKey: .id)
            name = try values.decode(String.self, forKey: .name)
            amount = try values.decodeIfPresent(Double.self, forKey: .amount)
                ?? values.decodeIfPresent(Double.self, forKey: .quantity)
                ?? 1
            unit = try values.decodeIfPresent(String.self, forKey: .unit) ?? "serving"
            estimatedGrams = try values.decodeIfPresent(Double.self, forKey: .estimatedGrams)
            caloriesKcal = try values.decode(Double.self, forKey: .caloriesKcal)
            proteinG = try values.decodeIfPresent(Double.self, forKey: .proteinG) ?? 0
            carbohydrateG = try values.decodeIfPresent(Double.self, forKey: .carbohydrateG)
                ?? values.decodeIfPresent(Double.self, forKey: .carbohydratesG)
                ?? 0
            fatG = try values.decodeIfPresent(Double.self, forKey: .fatG) ?? 0
            identificationConfidence = try values.decodeIfPresent(
                Double.self,
                forKey: .identificationConfidence
            )
            portionConfidence = try values.decodeIfPresent(Double.self, forKey: .portionConfidence)
            assumptions = try values.decodeIfPresent([String].self, forKey: .assumptions) ?? []
        }
    }

    var schemaVersion: Int
    var analysisId: UUID
    var title: String
    var items: [Item]
    var needsReview: Bool
    var reviewReason: String?
    var promptVersion: String?
    var modelVersion: String?

    func makeDraft(for request: MealAnalysisRequest) throws -> AnalyzedMealDraft {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty, !items.isEmpty else {
            throw MealAnalysisError.gatewayUnavailable(.malformedResponse)
        }

        let mappedItems = try items.map { item -> AnalyzedFoodItem in
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let unit = item.unit.trimmingCharacters(in: .whitespacesAndNewlines)
            let nutrition = NutritionValues(
                caloriesKcal: item.caloriesKcal,
                proteinGrams: item.proteinG,
                carbohydrateGrams: item.carbohydrateG,
                fatGrams: item.fatG
            )
            guard
                !name.isEmpty,
                item.amount.isFinite,
                item.amount > 0,
                nutrition.isValid,
                nutrition.caloriesKcal <= 20_000,
                nutrition.proteinGrams <= 2_000,
                nutrition.carbohydrateGrams <= 2_000,
                nutrition.fatGrams <= 2_000,
                item.identificationConfidence.isValidConfidence,
                item.portionConfidence.isValidConfidence,
                item.estimatedGrams.isValidPositiveMeasurement
            else {
                throw MealAnalysisError.gatewayUnavailable(.malformedResponse)
            }

            return AnalyzedFoodItem(
                id: item.id ?? UUID(),
                name: name,
                quantity: item.amount,
                unit: unit.isEmpty ? "serving" : unit,
                estimatedGrams: item.estimatedGrams,
                nutrition: nutrition,
                identificationConfidence: item.identificationConfidence,
                portionConfidence: item.portionConfidence,
                assumptions: item.assumptions
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        }

        return AnalyzedMealDraft(
            id: analysisId,
            loggedAt: request.loggedAt,
            title: cleanedTitle,
            inputSource: request.source,
            analysisRoute: .vertexFallback,
            items: mappedItems,
            needsReview: needsReview,
            reviewReason: reviewReason,
            promptVersion: promptVersion,
            modelVersion: modelVersion,
            protectedImagePath: request.protectedImagePath
        )
    }
}

private extension Optional where Wrapped == Double {
    var isValidConfidence: Bool {
        guard let value = self else { return true }
        return value.isFinite && (0...1).contains(value)
    }

    var isValidPositiveMeasurement: Bool {
        guard let value = self else { return true }
        return value.isFinite && value > 0
    }
}
