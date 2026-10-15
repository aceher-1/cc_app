import XCTest

final class CommonsUITests: XCTestCase {
    func testHalalFilterAndPreferencesSurviveRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-preferences"]
        app.launch()
        showMeal("Lunch", in: app)
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
        let disclosure = app.staticTexts["1 dish hidden by dietary filters"]
        XCTAssertTrue(disclosure.waitForExistence(timeout: 5))
        disclosure.tap()
        XCTAssertTrue(app.staticTexts["Sample bacon toast"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Excluded by your dietary filters"].exists)
        screenshot(app, name: "07-revealed-filtered-dishes")
        disclosure.tap()
        XCTAssertFalse(app.staticTexts["Sample bacon toast"].exists)
        disclosure.tap()
        XCTAssertTrue(app.staticTexts["Sample bacon toast"].exists)
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        showMeal("Lunch", in: app)
        XCTAssertTrue(app.staticTexts["Sample oatmeal"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Sample bacon toast"].exists)
        screenshot(app, name: "03-filtered-after-relaunch")
    }

    func testMealSelectionSwipesAndRefreshFeedback() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-preferences"]
        app.launch()
        showMeal("Breakfast", in: app)
        XCTAssertTrue(app.staticTexts["Sample pancakes"].exists)
        app.buttons["section.toggle.Test breakfast"].swipeLeft()
        assertSelected("Lunch", in: app)
        XCTAssertTrue(app.staticTexts["Sample oatmeal"].exists)
        app.buttons["section.toggle.Test station"].swipeLeft()
        assertSelected("Dinner", in: app)
        XCTAssertTrue(app.staticTexts["Sample baked tofu"].exists)
        app.buttons["section.toggle.Test dinner"].swipeLeft()
        assertSelected("Dinner", in: app)
        app.buttons["section.toggle.Test dinner"].swipeRight()
        assertSelected("Lunch", in: app)
        app.buttons["section.toggle.Test station"].swipeUp()
        assertSelected("Lunch", in: app)
        app.buttons["menu.refresh"].tap()
        XCTAssertTrue(app.staticTexts["refresh.confirmation"].waitForExistence(timeout: 5))
        assertSelected("Lunch", in: app)
        screenshot(app, name: "04-meal-selection-and-refresh")
    }

    func testCollapsedSectionsPersistAndCanBeReset() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-preferences"]
        app.launch()
        showMeal("Lunch", in: app)
        app.buttons["section.toggle.Test station"].tap()
        XCTAssertFalse(app.staticTexts["Sample oatmeal"].exists)
        XCTAssertEqual(app.buttons["section.toggle.Test station"].value as? String, "Collapsed")
        app.buttons["menu.refresh"].tap()
        XCTAssertTrue(app.staticTexts["refresh.confirmation"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Sample oatmeal"].exists)
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        showMeal("Lunch", in: app)
        XCTAssertEqual(app.buttons["section.toggle.Test station"].value as? String, "Collapsed")
        XCTAssertFalse(app.staticTexts["Sample oatmeal"].exists)
        app.buttons["layout.open"].tap()
        XCTAssertTrue(app.buttons["layout.reset"].waitForExistence(timeout: 5))
        screenshot(app, name: "05-organize-sections")
        app.buttons["layout.reset"].tap()
        app.buttons["layout.done"].tap()
        XCTAssertTrue(app.staticTexts["Sample oatmeal"].waitForExistence(timeout: 5))
        app.staticTexts["Sample oatmeal"].tap()
        XCTAssertTrue(app.navigationBars["Dish details"].waitForExistence(timeout: 5))
    }

    func testDraggingSectionOrderSurvivesRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-preferences"]
        app.launch()
        showMeal("Lunch", in: app)
        app.buttons["layout.open"].tap()
        XCTAssertTrue(app.buttons["layout.done"].waitForExistence(timeout: 5))
        let handles = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Reorder"))
        XCTAssertEqual(handles.count, 2, app.debugDescription)
        guard handles.count == 2 else { return }
        let salad = app.switches["layout.expanded.Test salad bar"]
        let station = app.switches["layout.expanded.Test station"]
        // The grip is shorter than its row. Drag above the actual row, not merely
        // to the top of the grip, so UIKit reliably crosses the insertion threshold.
        let start = handles.element(boundBy: 1).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let destination = app.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: handles.element(boundBy: 0).frame.midX, dy: station.frame.minY - 12))
        start.press(forDuration: 1, thenDragTo: destination, withVelocity: .slow, thenHoldForDuration: 1)
        let reordered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            salad.frame.minY < station.frame.minY
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [reordered], timeout: 5), .completed)
        app.buttons["layout.done"].tap()
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        showMeal("Lunch", in: app)
        XCTAssertLessThan(app.buttons["section.toggle.Test salad bar"].frame.minY,
                          app.buttons["section.toggle.Test station"].frame.minY)
        screenshot(app, name: "06-custom-section-order")
    }

    private func showMeal(_ name: String, in app: XCUIApplication) {
        let button = app.buttons["meal.\(name)"]
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        button.tap()
        assertSelected(name, in: app)
    }
    private func assertSelected(_ name: String, in app: XCUIApplication) {
        let button = app.buttons["meal.\(name)"]
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Selected"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
        XCTAssertEqual(app.staticTexts["meal.current"].label, name)
    }
    private func screenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
