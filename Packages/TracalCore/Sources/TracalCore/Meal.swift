import Foundation

public enum MealSource: String, Codable, CaseIterable, Hashable, Sendable {
    case manual
    case typedText
    case cameraPhoto
    case photoLibrary
    case nutritionLabel
    case repeatedMeal
}

public enum AnalysisRoute: String, Codable, CaseIterable, Hashable, Sendable {
    case manual
    case personalMatch
    case deterministicFallback
    case onDeviceText
    case visionOCR
    case onDeviceMultimodal
    case openAI
    case anthropic
    case gemini
    case vertexFallback
}

public enum AnalysisState: String, Codable, CaseIterable, Hashable, Sendable {
    case draft
    case queued
    case analyzing
    case needsReview
    case confirmed
    case failed

    public func canTransition(to next: AnalysisState) -> Bool {
        switch (self, next) {
        case let (current, next) where current == next:
            true
        case (.draft, .queued), (.draft, .analyzing), (.draft, .needsReview), (.draft, .failed),
             (.queued, .analyzing), (.queued, .failed),
             (.analyzing, .needsReview), (.analyzing, .failed),
             (.needsReview, .analyzing), (.needsReview, .confirmed), (.needsReview, .failed),
             (.failed, .queued), (.failed, .analyzing):
            true
        default:
            false
        }
    }
}

public enum PortionUnit: String, Codable, CaseIterable, Hashable, Sendable {
    case serving
    case piece
    case slice
    case gram
    case milliliter
    case cup
    case tablespoon
    case teaspoon
    case bowl
    case scoop
    case bottle
    case can
    case pack
    case custom
}

public struct MealItem: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var quantity: Double
    public var unit: PortionUnit
    public var customUnit: String?
    public var estimatedGrams: Double?
    /// Nutrition for the complete quantity represented by this item.
    public var nutrition: Nutrition
    public var identificationConfidence: Double?
    public var portionConfidence: Double?
    public var assumptions: [String]

    public init(
        id: UUID = UUID(),
        name: String,
        quantity: Double,
        unit: PortionUnit,
        customUnit: String? = nil,
        estimatedGrams: Double? = nil,
        nutrition: Nutrition,
        identificationConfidence: Double? = nil,
        portionConfidence: Double? = nil,
        assumptions: [String] = []
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.customUnit = customUnit
        self.estimatedGrams = estimatedGrams
        self.nutrition = nutrition
        self.identificationConfidence = identificationConfidence
        self.portionConfidence = portionConfidence
        self.assumptions = assumptions
    }
}

public struct MealDraft: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var analysisID: UUID?
    public var createdAt: Date
    public var updatedAt: Date
    public var source: MealSource
    public var analysisRoute: AnalysisRoute
    public var state: AnalysisState
    public var title: String
    public var originalText: String?
    public var protectedImagePath: String?
    public var items: [MealItem]
    public var confidence: Double?
    public var reviewReasons: [String]
    public var promptVersion: String?
    public var modelVersion: String?

    public init(
        id: UUID = UUID(),
        analysisID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        source: MealSource,
        analysisRoute: AnalysisRoute,
        state: AnalysisState = .draft,
        title: String,
        originalText: String? = nil,
        protectedImagePath: String? = nil,
        items: [MealItem] = [],
        confidence: Double? = nil,
        reviewReasons: [String] = [],
        promptVersion: String? = nil,
        modelVersion: String? = nil
    ) {
        self.id = id
        self.analysisID = analysisID
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.source = source
        self.analysisRoute = analysisRoute
        self.state = state
        self.title = title
        self.originalText = originalText
        self.protectedImagePath = protectedImagePath
        self.items = items
        self.confidence = confidence
        self.reviewReasons = reviewReasons
        self.promptVersion = promptVersion
        self.modelVersion = modelVersion
    }

    public var totals: Nutrition {
        Nutrition.total(of: items.lazy.map(\.nutrition))
    }

    public var needsReview: Bool {
        state == .needsReview || !reviewReasons.isEmpty
    }

    public mutating func transition(to next: AnalysisState, at date: Date = Date()) throws {
        guard state.canTransition(to: next) else {
            throw AnalysisTransitionError(from: state, to: next)
        }
        state = next
        updatedAt = date
    }

    public func confirmed(loggedAt: Date = Date()) throws -> MealEntry {
        let report = MealValidator.validate(self, forConfirmation: true)
        guard report.canConfirm else {
            throw MealConfirmationError(report: report)
        }
        return MealEntry(
            id: id,
            analysisID: analysisID,
            loggedAt: loggedAt,
            confirmedAt: loggedAt,
            source: source,
            analysisRoute: analysisRoute,
            title: title,
            items: items,
            confidence: confidence,
            thumbnailPath: protectedImagePath,
            promptVersion: promptVersion,
            modelVersion: modelVersion
        )
    }
}

public struct MealEntry: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var analysisID: UUID?
    public var loggedAt: Date
    public var confirmedAt: Date
    public var source: MealSource
    public var analysisRoute: AnalysisRoute
    public var title: String
    public var items: [MealItem]
    public var confidence: Double?
    public var thumbnailPath: String?
    public var promptVersion: String?
    public var modelVersion: String?

    public init(
        id: UUID = UUID(),
        analysisID: UUID? = nil,
        loggedAt: Date,
        confirmedAt: Date? = nil,
        source: MealSource,
        analysisRoute: AnalysisRoute,
        title: String,
        items: [MealItem],
        confidence: Double? = nil,
        thumbnailPath: String? = nil,
        promptVersion: String? = nil,
        modelVersion: String? = nil
    ) {
        self.id = id
        self.analysisID = analysisID
        self.loggedAt = loggedAt
        self.confirmedAt = confirmedAt ?? loggedAt
        self.source = source
        self.analysisRoute = analysisRoute
        self.title = title
        self.items = items
        self.confidence = confidence
        self.thumbnailPath = thumbnailPath
        self.promptVersion = promptVersion
        self.modelVersion = modelVersion
    }

    public var totals: Nutrition {
        Nutrition.total(of: items.lazy.map(\.nutrition))
    }

    public func duplicated(at date: Date = Date()) -> MealEntry {
        MealEntry(
            loggedAt: date,
            confirmedAt: date,
            source: .repeatedMeal,
            analysisRoute: .personalMatch,
            title: title,
            items: items.map {
                var copy = $0
                copy.id = UUID()
                return copy
            },
            confidence: 1,
            thumbnailPath: thumbnailPath,
            promptVersion: promptVersion,
            modelVersion: modelVersion
        )
    }
}

public struct AnalysisTransitionError: Error, Codable, Hashable, Sendable {
    public var from: AnalysisState
    public var to: AnalysisState

    public init(from: AnalysisState, to: AnalysisState) {
        self.from = from
        self.to = to
    }
}

public struct MealConfirmationError: Error, Sendable {
    public var report: ValidationReport

    public init(report: ValidationReport) {
        self.report = report
    }
}
