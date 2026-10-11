import XCTest

final class CommonsUITests: XCTestCase {
    func testHalalFilterAndPreferencesSurviveRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-preferences"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Sample oatmeal"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Sample bacon toast"].exists)
        screenshot(app, name: "01-menu")
        app.buttons["filters.open"].tap()
        let halal = app.switches["filter.halal"]
        if !halal.isHittable { app.swipeUp(); app.swipeUp() }
        XCTAssertTrue(halal.waitForExistence(timeout: 5))
        // SwiftUI exposes the full form row as a switch. Tap the actual control at its trailing edge.
        halal.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let enabled = NSPredicate(format: "value == %@", "1")
        XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: enabled, object: halal)], timeout: 5) == .completed)
        screenshot(app, name: "02-filters")
        app.buttons["filters.done"].tap()
        XCTAssertTrue(app.staticTexts["Sample oatmeal"].exists)
        XCTAssertFalse(app.staticTexts["Sample bacon toast"].exists)
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Sample oatmeal"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Sample bacon toast"].exists)
        screenshot(app, name: "03-filtered-after-relaunch")
    }
    private func screenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
