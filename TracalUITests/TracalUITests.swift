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
    private func keepScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
