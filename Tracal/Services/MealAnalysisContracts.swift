import Foundation

/// The local draft shared by every analyzer and the persistence boundary. It
/// deliberately contains no persistence types, so analyzers cannot write to
/// SwiftData directly.
public struct AnalyzedMealDraft: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var loggedAt: Date
    public var title: String
    public var inputSource: MealInputSource
    public var analysisRoute: MealAnalysisRoute
    public var items: [AnalyzedFoodItem]
    public var needsReview: Bool
    public var reviewReason: String?
    public var promptVersion: String?
    public var modelVersion: String?
    public var originalDescription: String?
    public var protectedImagePath: String?

    public init(
        id: UUID = UUID(),
        loggedAt: Date = .now,
        title: String,
        inputSource: MealInputSource,
        analysisRoute: MealAnalysisRoute,
        items: [AnalyzedFoodItem],
        needsReview: Bool = true,
        reviewReason: String? = nil,
        promptVersion: String? = nil,
        modelVersion: String? = nil,
        originalDescription: String? = nil,
        protectedImagePath: String? = nil
    ) {
        self.id = id
        self.loggedAt = loggedAt
        self.title = title
        self.inputSource = inputSource
        self.analysisRoute = analysisRoute
        self.items = items
        self.needsReview = needsReview
        self.reviewReason = reviewReason
        self.promptVersion = promptVersion
        self.modelVersion = modelVersion
        self.originalDescription = originalDescription
        self.protectedImagePath = protectedImagePath
    }

    public var totals: NutritionValues {
        items.reduce(.zero) { partial, item in
            partial + item.nutrition
        }
    }

    public var canBeConfirmed: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !items.isEmpty
            && items.allSatisfy(\.canBeConfirmed)
    }

    public mutating func normalizeForConfirmation() {
        title = title.trimmed(or: "Meal")
        items = items.map { item in
            var normalized = item
            normalized.name = item.name.trimmed(or: "Food")
            normalized.unit = item.unit.trimmed(or: "serving")
            normalized.quantity = item.quantity.finiteNonnegative
            normalized.estimatedGrams = item.estimatedGrams?.finiteNonnegative
            normalized.nutrition = item.nutrition.normalized
            normalized.assumptions = item.assumptions
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return normalized
        }
        needsReview = false
    }
}

public struct AnalyzedFoodItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var quantity: Double
    public var unit: String
    public var estimatedGrams: Double?
    public var nutrition: NutritionValues
    public var identificationConfidence: Double?
    public var portionConfidence: Double?
    public var assumptions: [String]

    public init(
        id: UUID = UUID(),
        name: String,
        quantity: Double = 1,
        unit: String = "serving",
        estimatedGrams: Double? = nil,
        nutrition: NutritionValues = .zero,
        identificationConfidence: Double? = nil,
        portionConfidence: Double? = nil,
        assumptions: [String] = []
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.estimatedGrams = estimatedGrams
        self.nutrition = nutrition
        self.identificationConfidence = identificationConfidence
        self.portionConfidence = portionConfidence
        self.assumptions = assumptions
    }

    public var canBeConfirmed: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && quantity.isFinite
            && quantity > 0
            && nutrition.isValid
    }
}

public struct NutritionValues: Codable, Hashable, Sendable {
    public var caloriesKcal: Double
    public var proteinGrams: Double
    public var carbohydrateGrams: Double
    public var fatGrams: Double

    public init(
        caloriesKcal: Double = 0,
        proteinGrams: Double = 0,
        carbohydrateGrams: Double = 0,
        fatGrams: Double = 0
    ) {
        self.caloriesKcal = caloriesKcal
        self.proteinGrams = proteinGrams
        self.carbohydrateGrams = carbohydrateGrams
        self.fatGrams = fatGrams
    }

    public static let zero = NutritionValues()

    public var isValid: Bool {
        caloriesKcal.isFinite
            && proteinGrams.isFinite
            && carbohydrateGrams.isFinite
            && fatGrams.isFinite
            && caloriesKcal >= 0
            && proteinGrams >= 0
            && carbohydrateGrams >= 0
            && fatGrams >= 0
    }

    public var normalized: NutritionValues {
        NutritionValues(
            caloriesKcal: caloriesKcal.finiteNonnegative,
            proteinGrams: proteinGrams.finiteNonnegative,
            carbohydrateGrams: carbohydrateGrams.finiteNonnegative,
            fatGrams: fatGrams.finiteNonnegative
        )
    }

    public static func + (lhs: NutritionValues, rhs: NutritionValues) -> NutritionValues {
        NutritionValues(
            caloriesKcal: lhs.caloriesKcal + rhs.caloriesKcal,
            proteinGrams: lhs.proteinGrams + rhs.proteinGrams,
            carbohydrateGrams: lhs.carbohydrateGrams + rhs.carbohydrateGrams,
            fatGrams: lhs.fatGrams + rhs.fatGrams
        )
    }
}

public enum MealInputSource: String, Codable, Hashable, Sendable, CaseIterable {
    case typedText
    case manual
    case cameraPhoto
    case photoLibrary
}

public enum MealAnalysisRoute: String, Codable, Hashable, Sendable {
    case manual
    case deterministic
    case onDeviceFoundationModel
    case onDeviceMultimodal
    case visionNutritionLabel
    case vertexFallback
}

public struct SanitizedMealImage: Hashable, Sendable {
    public var data: Data
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var mimeType: String

    public init(
        data: Data,
        pixelWidth: Int,
        pixelHeight: Int,
        mimeType: String = "image/jpeg"
    ) {
        self.data = data
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.mimeType = mimeType
    }
}

public enum MealAnalysisInput: Sendable {
    case text(String)
    case photo(SanitizedMealImage, hint: String?)
}

public struct MealAnalysisRequest: Sendable {
    public var id: UUID
    public var loggedAt: Date
    public var source: MealInputSource
    public var input: MealAnalysisInput
    public var protectedImagePath: String?

    public init(
        id: UUID = UUID(),
        loggedAt: Date,
        source: MealInputSource,
        input: MealAnalysisInput,
        protectedImagePath: String? = nil
    ) {
        self.id = id
        self.loggedAt = loggedAt
        self.source = source
        self.input = input
        self.protectedImagePath = protectedImagePath
    }
}

public protocol MealAnalysisRouting: Sendable {
    func analyze(_ request: MealAnalysisRequest) async throws -> AnalyzedMealDraft
    func localModelAvailability() async -> LocalModelAvailability
}

public enum LocalModelAvailability: Codable, Hashable, Sendable {
    case available
    case unsupportedOperatingSystem
    case deviceNotEligible
    case appleIntelligenceDisabled
    case modelNotReady
    case unavailable(reason: String)

    public var isAvailable: Bool {
        self == .available
    }

    public var userMessage: String {
        switch self {
        case .available:
            return "Apple Intelligence is ready on this iPhone."
        case .unsupportedOperatingSystem:
            return "On-device meal parsing needs iOS 26 or later."
        case .deviceNotEligible:
            return "This device cannot run the on-device language model."
        case .appleIntelligenceDisabled:
            return "Turn on Apple Intelligence in Settings to analyze text on device."
        case .modelNotReady:
            return "Apple Intelligence is still preparing its on-device model."
        case .unavailable(let reason):
            return reason
        }
    }
}

public enum MealAnalysisError: Error, Hashable, Sendable {
    case emptyInput
    case unreadableImage
    case noFoodDetected
    case noNutritionDetected
    case localModelUnavailable(LocalModelAvailability)
    case invalidModelResponse(String)
    case vertexNotConfigured
    case gatewayUnavailable(VertexGatewayFailure)
    case imageStorageFailed
    case cancelled
}

public enum VertexGatewayFailure: Hashable, Sendable {
    case notConfigured
    case invalidEndpoint
    case authorizationUnavailable
    case networkUnavailable
    case rejected(statusCode: Int)
    case requestTooLarge
    case responseTooLarge
    case malformedResponse
}

extension MealAnalysisError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Describe the meal first."
        case .unreadableImage:
            return "That image could not be read. Try another photo."
        case .noFoodDetected:
            return "No food or drink was found in that photo."
        case .noNutritionDetected:
            return "No readable nutrition values were found."
        case .localModelUnavailable(let availability):
            return availability.userMessage
        case .invalidModelResponse:
            return "The meal estimate was incomplete. Try again."
        case .vertexNotConfigured:
            return "The private meal-analysis gateway is not configured yet."
        case .gatewayUnavailable(let reason):
            switch reason {
            case .notConfigured:
                return "The private meal-analysis gateway is not configured yet."
            case .invalidEndpoint:
                return "The private meal-analysis gateway address is invalid."
            case .authorizationUnavailable:
                return "Private meal analysis needs authorization."
            case .networkUnavailable:
                return "The private meal-analysis gateway could not be reached."
            case .rejected(let statusCode):
                return statusCode == 429
                    ? "The private meal-analysis limit was reached."
                    : "The private meal-analysis request was rejected."
            case .requestTooLarge:
                return "The meal photo is too large to analyze."
            case .responseTooLarge, .malformedResponse:
                return "The private meal-analysis response could not be used."
            }
        case .imageStorageFailed:
            return "The protected photo draft could not be saved."
        case .cancelled:
            return "Analysis was cancelled."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .vertexNotConfigured, .gatewayUnavailable, .invalidModelResponse, .localModelUnavailable:
            return "Check your connection and try again. Your inputs are still here."
        case .unreadableImage, .noNutritionDetected:
            return "Retake the photo in brighter, even light."
        case .noFoodDetected:
            return "Try another photo or describe what you ate."
        default:
            return nil
        }
    }
}

private extension String {
    func trimmed(or fallback: String) -> String {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? fallback : value
    }
}

private extension Double {
    var finiteNonnegative: Double {
        guard isFinite else { return 0 }
        return max(0, self)
    }
}
