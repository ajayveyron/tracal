import Foundation
import SwiftData

enum PendingAnalysisState: String, Codable {
    case queued
    case uploading
    case waitingForConnectivity
    case failed
}

@Model
final class PendingAnalysis {
    var id: UUID
    var requestID: UUID
    var createdAt: Date
    var updatedAt: Date
    var protectedPayloadRelativePath: String?
    var attemptCount: Int
    var nextRetryAt: Date?
    var stateRawValue: String
    var failureCode: String?

    init(
        id: UUID = UUID(),
        requestID: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        protectedPayloadRelativePath: String? = nil,
        attemptCount: Int = 0,
        nextRetryAt: Date? = nil,
        state: PendingAnalysisState = .queued,
        failureCode: String? = nil
    ) {
        self.id = id
        self.requestID = requestID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.protectedPayloadRelativePath = protectedPayloadRelativePath
        self.attemptCount = max(0, attemptCount)
        self.nextRetryAt = nextRetryAt
        self.stateRawValue = state.rawValue
        self.failureCode = failureCode
    }

    var state: PendingAnalysisState {
        get { PendingAnalysisState(rawValue: stateRawValue) ?? .queued }
        set { stateRawValue = newValue.rawValue }
    }
}

