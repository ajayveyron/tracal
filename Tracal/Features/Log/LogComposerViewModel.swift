import Combine
import Foundation

@MainActor
final class LogComposerViewModel: ObservableObject {
    @Published var typedDescription = ""
    @Published var previewImageData: Data?
    @Published var draft: AnalyzedMealDraft?
    @Published var isAnalyzing = false
    @Published private(set) var isPreparingPhoto = false
    @Published var localModelAvailability: LocalModelAvailability?
    @Published var errorMessage: String?
    @Published var recoveryMessage: String?

    let loggedAt: Date

    private let analyzer: any MealAnalysisRouting
    private let imageSanitizer: MealImageSanitizer
    private let imageStore: ProtectedMealImageStore
    private var analysisTask: Task<Void, Never>?
    private var pendingImagePath: String?
    private var pendingPhotoSource: MealInputSource?
    private var pendingSanitizedImage: SanitizedMealImage?
    private var pendingRequestID: UUID?
    private var didCommit = false

    init(
        loggedAt: Date,
        analyzer: any MealAnalysisRouting,
        imageSanitizer: MealImageSanitizer = MealImageSanitizer(),
        imageStore: ProtectedMealImageStore = ProtectedMealImageStore()
    ) {
        self.loggedAt = loggedAt
        self.analyzer = analyzer
        self.imageSanitizer = imageSanitizer
        self.imageStore = imageStore
    }

    deinit {
        analysisTask?.cancel()
    }

    func loadLocalModelAvailability() {
        Task { [weak self, analyzer] in
            let value = await analyzer.localModelAvailability()
            guard let self else { return }
            localModelAvailability = value
        }
    }

    /// Deterministic image injection for simulator UI tests. Release builds and
    /// ordinary Debug launches never inspect or decode this environment value.
    func ingestUITestFixtureIfPresent() {
        #if DEBUG
        let process = ProcessInfo.processInfo
        guard
            process.arguments.contains("-ui-testing"),
            previewImageData == nil,
            let encoded = process.environment["TRACAL_UI_TEST_IMAGE_BASE64"],
            let data = Data(base64Encoded: encoded),
            !data.isEmpty
        else {
            return
        }
        ingestPhotoData(data, source: .photoLibrary)
        #endif
    }

    func analyzeMeal() {
        let text = typedDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        if let image = pendingSanitizedImage,
           let source = pendingPhotoSource,
           let requestID = pendingRequestID {
            let request = MealAnalysisRequest(
                id: requestID,
                loggedAt: loggedAt,
                source: source,
                input: .photo(image, hint: text.isEmpty ? nil : text),
                protectedImagePath: pendingImagePath
            )
            runAnalysis(request)
            return
        }

        guard !text.isEmpty else {
            show(MealAnalysisError.emptyInput)
            return
        }

        let request = MealAnalysisRequest(
            loggedAt: loggedAt,
            source: .typedText,
            input: .text(text)
        )
        runAnalysis(request)
    }

    func ingestPhotoData(_ data: Data, source: MealInputSource) {
        analysisTask?.cancel()
        clearError()
        isAnalyzing = true
        isPreparingPhoto = true
        draft = nil

        let sanitizer = imageSanitizer
        let store = imageStore
        let oldPath = pendingImagePath
        let requestID = UUID()

        analysisTask = Task { [weak self] in
            guard let self else { return }
            do {
                let sanitized = try await Task.detached(priority: .userInitiated) {
                    try sanitizer.sanitize(data)
                }.value
                try Task.checkCancellation()

                if let oldPath {
                    await store.remove(path: oldPath)
                }
                let fileURL = try await store.save(sanitized, id: requestID)
                let relativePath = await store.relativePath(for: fileURL)
                try Task.checkCancellation()

                previewImageData = sanitized.data
                pendingImagePath = relativePath
                pendingPhotoSource = source
                pendingSanitizedImage = sanitized
                pendingRequestID = requestID
            } catch is CancellationError {
                // A replacement request owns the visible state.
            } catch {
                show(error)
            }
            isPreparingPhoto = false
            isAnalyzing = false
        }
    }

    func confirmedDraft() -> AnalyzedMealDraft? {
        guard var value = draft else { return nil }
        value.normalizeForConfirmation()
        guard value.canBeConfirmed else {
            draft = nil
            errorMessage = "Complete the food name and use valid, nonnegative nutrition values."
            recoveryMessage = nil
            return nil
        }
        didCommit = true
        draft = nil
        return value
    }

    func discard() async {
        analysisTask?.cancel()
        guard !didCommit else { return }
        await imageStore.remove(path: pendingImagePath)
        pendingImagePath = nil
    }

    func removePendingPhoto() async {
        analysisTask?.cancel()
        isAnalyzing = false
        await imageStore.remove(path: pendingImagePath)
        pendingImagePath = nil
        pendingPhotoSource = nil
        pendingSanitizedImage = nil
        pendingRequestID = nil
        previewImageData = nil
        clearError()
    }

    func cancelAnalysis() {
        analysisTask?.cancel()
        isPreparingPhoto = false
        isAnalyzing = false
    }

    func reportPhotoLoadFailure() {
        show(MealAnalysisError.unreadableImage)
    }

    func clearError() {
        errorMessage = nil
        recoveryMessage = nil
    }

    private func runAnalysis(_ request: MealAnalysisRequest) {
        analysisTask?.cancel()
        clearError()
        isPreparingPhoto = false
        isAnalyzing = true

        analysisTask = Task { [weak self, analyzer] in
            guard let self else { return }
            do {
                let value = try await analyzer.analyze(request)
                try Task.checkCancellation()
                draft = value
            } catch is CancellationError {
                // Replaced or explicitly cancelled.
            } catch {
                show(error)
            }
            isAnalyzing = false
        }
    }

    private func show(_ error: Error) {
        guard !(error is CancellationError) else { return }
        if let analysisError = error as? MealAnalysisError {
            errorMessage = analysisError.errorDescription
            recoveryMessage = analysisError.recoverySuggestion
        } else {
            errorMessage = "Analysis could not finish."
            recoveryMessage = "Check your connection and try again. Your inputs are still here."
        }
    }
}
