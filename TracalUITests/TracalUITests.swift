import UIKit
import XCTest

final class TracalUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testComposerShowsOnlyDescriptionAndPhotoInputs() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()

        let logButton = app.buttons["today.log"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 8))
        logButton.tap()

        XCTAssertTrue(app.textViews["log.description"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["log.camera"].exists)
        XCTAssertTrue(app.buttons["log.photos"].exists)
        XCTAssertTrue(app.buttons["log.analyze"].exists)
        XCTAssertFalse(app.buttons["log.manual"].exists)

        let description = app.textViews["log.description"]
        description.tap()
        description.typeText("Eggs and toast")
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3))
        XCTAssertLessThanOrEqual(app.buttons["log.camera"].frame.maxY, keyboard.frame.minY + 1)
        XCTAssertLessThanOrEqual(app.buttons["log.photos"].frame.maxY, keyboard.frame.minY + 1)
        XCTAssertTrue(app.buttons["log.analyze"].isHittable)

        let composer = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        composer.name = "Unified description and photo composer"
        composer.lifetime = .keepAlways
        add(composer)
    }

    @MainActor
    func testVisibleTextMealFlow() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()

        let logButton = app.buttons["today.log"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 8))
        logButton.tap()

        let description = app.textViews["log.description"]
        XCTAssertTrue(description.waitForExistence(timeout: 5))
        description.tap()
        description.typeText("Protein shake, 420 kcal, 32 g protein, 45 g carbs, 12 g fat")

        let analyzeButton = app.buttons["log.analyze"]
        XCTAssertTrue(analyzeButton.isEnabled)
        analyzeButton.tap()

        let savedMeal = app.descendants(matching: .any)["today.meal"].firstMatch
        XCTAssertTrue(savedMeal.waitForExistence(timeout: 8))
        XCTAssertFalse(app.navigationBars["Review"].exists)
        XCTAssertTrue(savedMeal.label.contains("Protein shake"))
        XCTAssertTrue(savedMeal.label.contains("420"))
    }

    @MainActor
    func testButtonHierarchyVisualAudit() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()

        XCTAssertTrue(app.buttons["today.settings"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["today.header.date"].exists)

        let dateButtons = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "today.date.")
        )
        XCTAssertEqual(dateButtons.count, 5)
        let visibleDatesBeforeSelection = (0..<dateButtons.count).map {
            dateButtons.element(boundBy: $0).identifier
        }
        dateButtons.element(boundBy: 1).tap()
        let visibleDatesAfterSelection = (0..<dateButtons.count).map {
            dateButtons.element(boundBy: $0).identifier
        }
        XCTAssertEqual(visibleDatesAfterSelection, visibleDatesBeforeSelection)

        app.buttons["today.dates.next"].tap()
        let visibleDatesAfterNextPage = (0..<dateButtons.count).map {
            dateButtons.element(boundBy: $0).identifier
        }
        XCTAssertNotEqual(visibleDatesAfterNextPage, visibleDatesBeforeSelection)
        XCTAssertTrue(
            app.buttons["today.dates.previous"].label.contains("Today is this way")
        )
        keepScreenshot(named: "Button audit - Today direction arrow")

        app.buttons["today.dates.previous"].tap()
        let visibleDatesAfterReturning = (0..<dateButtons.count).map {
            dateButtons.element(boundBy: $0).identifier
        }
        XCTAssertEqual(visibleDatesAfterReturning, visibleDatesBeforeSelection)
        XCTAssertTrue(app.staticTexts["today.header.date"].exists)
        keepScreenshot(named: "Button audit - Today empty")

        app.buttons["today.settings"].tap()
        XCTAssertTrue(app.buttons["settings.goal"].waitForExistence(timeout: 5))
        keepScreenshot(named: "Button audit - Settings rows")

        app.buttons["settings.goal"].tap()
        XCTAssertTrue(app.buttons["goal.save"].waitForExistence(timeout: 5))
        keepScreenshot(named: "Button audit - Goal form")
        app.buttons["Cancel"].tap()
        app.buttons["settings.done"].tap()

        app.buttons["today.log"].tap()
        let description = app.textViews["log.description"]
        XCTAssertTrue(description.waitForExistence(timeout: 5))
        keepScreenshot(named: "Button audit - Composer")
        description.tap()
        description.typeText("Protein shake, 420 kcal, 32 g protein, 45 g carbs, 12 g fat")
        app.buttons["log.analyze"].tap()

        let savedMeal = app.descendants(matching: .any)["today.meal"].firstMatch
        XCTAssertTrue(savedMeal.waitForExistence(timeout: 8))
        XCTAssertEqual(app.staticTexts["today.entry.count"].label, "1 entry")
        keepScreenshot(named: "Button audit - One saved entry")

        savedMeal.tap()
        XCTAssertTrue(app.buttons["entry.save"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["entry.delete"].exists)
        keepScreenshot(named: "Button audit - Meal details")
    }

    @MainActor
    func testLiveGatewayTypedMealFlow() async throws {
        guard await liveGatewayIsReady() else {
            throw XCTSkip("Start the local private model gateway to run this live UI test.")
        }

        let meal = ProcessInfo.processInfo.environment["TRACAL_LIVE_MEAL"]
            ?? "Two masala dosas with coconut chutney and one small filter coffee with milk and sugar"
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launchEnvironment["TRACAL_GATEWAY_BASE_URL"] = "http://127.0.0.1:8080"
        app.launchEnvironment["TRACAL_ALLOW_INSECURE_LOCAL"] = "true"
        app.launch()

        let logButton = app.buttons["today.log"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 8))
        logButton.tap()

        let description = app.textViews["log.description"]
        XCTAssertTrue(description.waitForExistence(timeout: 5))
        description.tap()
        description.typeText(meal)

        let analyze = app.buttons["log.analyze"]
        XCTAssertTrue(analyze.isEnabled)
        analyze.tap()

        let pulse = app.descendants(matching: .any)["log.analysis.pulse"]
        XCTAssertTrue(pulse.waitForExistence(timeout: 3))
        let analyzingState = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        analyzingState.name = "Non-modal pulsing analysis state"
        analyzingState.lifetime = .keepAlways
        add(analyzingState)

        let savedMeal = app.descendants(matching: .any)["today.meal"].firstMatch
        XCTAssertTrue(savedMeal.waitForExistence(timeout: 55))
        XCTAssertFalse(app.navigationBars["Review"].exists)
        XCTAssertFalse(savedMeal.label.contains("0 kcal"))
        XCTAssertEqual(savedMeal.value as? String, "vertexFallback")

        let finalState = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        finalState.name = "Live gateway meal saved on Today"
        finalState.lifetime = .keepAlways
        add(finalState)

        savedMeal.tap()
        XCTAssertTrue(app.navigationBars["Meal"].waitForExistence(timeout: 5))
        let originalDescription = app.descendants(matching: .any)["entry.original.description"]
        XCTAssertTrue(originalDescription.waitForExistence(timeout: 3))
        XCTAssertTrue(originalDescription.label.contains("masala dosas"))
        XCTAssertTrue(app.descendants(matching: .any)["entry.nutrition.summary"].exists)
        XCTAssertFalse(app.staticTexts["Items"].exists)

        let detailState = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        detailState.name = "Stored original input and compact nutrition"
        detailState.lifetime = .keepAlways
        add(detailState)
    }

    @MainActor
    func testLiveGatewayImageOnlySavesAndReopensOriginalPhoto() async throws {
        guard await liveGatewayIsReady() else {
            throw XCTSkip("Start the local private model gateway to run this live UI test.")
        }
        let app = try launchLiveGatewayAppWithSushi()

        app.buttons["today.log"].tap()
        XCTAssertTrue(app.images["log.photo.preview"].waitForExistence(timeout: 10))

        let analyze = app.buttons["log.analyze"]
        waitUntilEnabled(analyze, timeout: 10)
        analyze.tap()

        let pulse = app.descendants(matching: .any)["log.analysis.pulse"]
        XCTAssertTrue(pulse.waitForExistence(timeout: 3))
        keepScreenshot(named: "Sushi image-only analysis pulse")

        let savedMeal = app.descendants(matching: .any)["today.meal"].firstMatch
        XCTAssertTrue(savedMeal.waitForExistence(timeout: 55))
        XCTAssertFalse(app.navigationBars["Review"].exists, "Analysis should save directly.")
        XCTAssertEqual(savedMeal.value as? String, "vertexFallback")
        XCTAssertFalse(savedMeal.label.contains("0 kcal"))
        keepScreenshot(named: "Sushi image-only saved on Today")

        savedMeal.tap()
        XCTAssertTrue(app.navigationBars["Meal"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.images["entry.original.image"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["entry.original.description"].exists)
        keepScreenshot(named: "Sushi image-only reopened detail")
    }

    @MainActor
    func testLiveGatewayTextAndImageSavesAndReopensBothOriginalInputs() async throws {
        guard await liveGatewayIsReady() else {
            throw XCTSkip("Start the local private model gateway to run this live UI test.")
        }
        let description = "I ate all 8 sushi pieces shown, including all toppings."
        let app = try launchLiveGatewayAppWithSushi()

        app.buttons["today.log"].tap()
        XCTAssertTrue(app.images["log.photo.preview"].waitForExistence(timeout: 10))

        let descriptionEditor = app.textViews["log.description"]
        XCTAssertTrue(descriptionEditor.waitForExistence(timeout: 5))
        descriptionEditor.tap()
        descriptionEditor.typeText(description)

        let analyze = app.buttons["log.analyze"]
        waitUntilEnabled(analyze, timeout: 10)
        analyze.tap()

        let pulse = app.descendants(matching: .any)["log.analysis.pulse"]
        XCTAssertTrue(pulse.waitForExistence(timeout: 3))
        keepScreenshot(named: "Sushi text-and-image analysis pulse")

        let savedMeal = app.descendants(matching: .any)["today.meal"].firstMatch
        XCTAssertTrue(savedMeal.waitForExistence(timeout: 55))
        XCTAssertFalse(app.navigationBars["Review"].exists, "Analysis should save directly.")
        XCTAssertEqual(savedMeal.value as? String, "vertexFallback")
        XCTAssertFalse(savedMeal.label.contains("0 kcal"))
        keepScreenshot(named: "Sushi text-and-image saved on Today")

        savedMeal.tap()
        XCTAssertTrue(app.navigationBars["Meal"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.images["entry.original.image"].waitForExistence(timeout: 5))
        let originalDescription = app.descendants(matching: .any)["entry.original.description"]
        XCTAssertTrue(originalDescription.waitForExistence(timeout: 5))
        XCTAssertTrue(originalDescription.label.contains(description))
        keepScreenshot(named: "Sushi text-and-image reopened detail")
    }

    @MainActor
    private func liveGatewayIsReady() async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:8080/healthz") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    @MainActor
    private func launchLiveGatewayAppWithSushi() throws -> XCUIApplication {
        let fixtureURL = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "sushi-e2e", withExtension: "jpg")
        )
        let fixtureData = try Data(contentsOf: fixtureURL)
        XCTAssertLessThan(fixtureData.count, 200_000, "Keep launch-environment fixture compact.")

        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launchEnvironment["TRACAL_GATEWAY_BASE_URL"] = "http://127.0.0.1:8080"
        app.launchEnvironment["TRACAL_ALLOW_INSECURE_LOCAL"] = "true"
        app.launchEnvironment["TRACAL_UI_TEST_IMAGE_BASE64"] = fixtureData.base64EncodedString()
        app.launch()
        XCTAssertTrue(app.buttons["today.log"].waitForExistence(timeout: 8))
        return app
    }

    @MainActor
    private func waitUntilEnabled(_ element: XCUIElement, timeout: TimeInterval) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"),
            object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed)
    }

    private func keepScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
