import XCTest
import UIKit
@testable import Tracal

@MainActor
final class TracalAppTests: XCTestCase {
    func testAppModuleLoads() {
        XCTAssertTrue(true)
    }

    func testWidgetDeepLinksResolveEveryLaunchMode() throws {
        for mode in MealLogLaunchMode.allCases {
            XCTAssertEqual(MealLogLaunchMode(url: mode.deepLinkURL), mode)
        }
    }

    func testUnrelatedDeepLinksAreIgnored() throws {
        XCTAssertNil(MealLogLaunchMode(url: try XCTUnwrap(URL(string: "https://example.com/log/text"))))
        XCTAssertNil(MealLogLaunchMode(url: try XCTUnwrap(URL(string: "tracal://history/text"))))
        XCTAssertNil(MealLogLaunchMode(url: try XCTUnwrap(URL(string: "tracal://log/barcode"))))
    }

    func testUnifiedComposerSendsTextOnlyAsTypedInput() async throws {
        let analyzer = RecordingMealAnalyzer()
        let model = LogComposerViewModel(loggedAt: .now, analyzer: analyzer)
        model.typedDescription = "Two eggs and toast"

        model.analyzeMeal()
        await waitUntil { model.draft != nil }

        let request = await analyzer.lastRequest()
        guard case .text(let text) = request?.input else {
            return XCTFail("Expected a typed-text request.")
        }
        XCTAssertEqual(text, "Two eggs and toast")
        XCTAssertEqual(request?.source, .typedText)
    }

    func testUnifiedComposerUsesDescriptionAsImageContextWhenBothArePresent() async throws {
        let analyzer = RecordingMealAnalyzer()
        let model = LogComposerViewModel(loggedAt: .now, analyzer: analyzer)
        model.typedDescription = "I ate the whole plate and used one tablespoon of oil"

        model.ingestPhotoData(makeJPEG(), source: .photoLibrary)
        await waitUntil { model.previewImageData != nil && !model.isAnalyzing }

        model.analyzeMeal()
        await waitUntil { model.draft != nil }

        let request = await analyzer.lastRequest()
        guard case .photo(_, let hint) = request?.input else {
            return XCTFail("Expected a photo request.")
        }
        XCTAssertEqual(hint, "I ate the whole plate and used one tablespoon of oil")
        XCTAssertEqual(request?.source, .photoLibrary)
        XCTAssertNotNil(request?.protectedImagePath)
        await model.discard()
    }

    func testNonFoodPhotoKeepsComposerOpenWithErrorAndNoDraft() async throws {
        let model = LogComposerViewModel(loggedAt: .now, analyzer: NonFoodMealAnalyzer())

        model.ingestPhotoData(makeJPEG(), source: .cameraPhoto)
        await waitUntil { model.previewImageData != nil && !model.isAnalyzing }

        model.analyzeMeal()
        await waitUntil { model.errorMessage != nil && !model.isAnalyzing }

        XCTAssertNil(model.draft)
        XCTAssertNotNil(model.previewImageData)
        XCTAssertEqual(model.errorMessage, "No food or drink was found in that photo.")
        XCTAssertEqual(model.recoveryMessage, "Try another photo or describe what you ate.")
        await model.discard()
    }

    private func waitUntil(
        timeout: Duration = .seconds(4),
        condition: @escaping @MainActor () -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("Timed out waiting for the composer state.")
    }

    private func makeJPEG() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
        return renderer.jpegData(withCompressionQuality: 0.9) { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
    }
}

private actor NonFoodMealAnalyzer: MealAnalysisRouting {
    func analyze(_ request: MealAnalysisRequest) async throws -> AnalyzedMealDraft {
        throw MealAnalysisError.noFoodDetected
    }

    func localModelAvailability() async -> LocalModelAvailability {
        .available
    }
}

private actor RecordingMealAnalyzer: MealAnalysisRouting {
    private var requests: [MealAnalysisRequest] = []

    func analyze(_ request: MealAnalysisRequest) async throws -> AnalyzedMealDraft {
        requests.append(request)
        return AnalyzedMealDraft(
            id: request.id,
            loggedAt: request.loggedAt,
            title: "Fixture meal",
            inputSource: request.source,
            analysisRoute: .vertexFallback,
            items: [
                AnalyzedFoodItem(
                    name: "Fixture food",
                    nutrition: NutritionValues(caloriesKcal: 250)
                )
            ],
            needsReview: true
        )
    }

    func localModelAvailability() async -> LocalModelAvailability {
        .available
    }

    func lastRequest() -> MealAnalysisRequest? {
        requests.last
    }
}
