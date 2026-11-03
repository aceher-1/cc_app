import XCTest
#if canImport(CommonsCore)
@testable import CommonsCore
#else
@testable import Commons
#endif

final class MealPlanTests: XCTestCase {
    private func items() throws -> [MenuItem] {
        let source = #"[{"name":"Lunch","groups":[{"name":"Grill","items":[{"name":"Tofu","protein":"15g","carbohydrates":"2 g","calories":"180"},{"name":"Rice","protein":"4","carbohydrates":"45g"},{"name":"Unknown","protein":"N/A","carbohydrates":"-1"},{"name":"Tea","protein":"0","carbohydrates":"0g"}]}]}]"#
        return try MenuParser.parse(Data(source.utf8), dateKey: "2026-11-03", fetchedAt: Date()).meals[0].stations[0].items
    }

    func testRankingUsesReportedValuesAndKeepsRealZero() throws {
        let items = try items()
        XCTAssertEqual(MealPlan.ranked(items, goal: .protein).map(\.name), ["Tofu", "Rice", "Tea"])
        XCTAssertEqual(MealPlan.ranked(items, goal: .carbs).map(\.name), ["Tea", "Tofu", "Rice"])
        XCTAssertEqual(MealPlan.ranked(items, goal: .all).count, 4)
    }

    func testWholeServingsAndPartialTotalsSurviveSaving() throws {
        let items = try items()
        var plan = MealPlan()
        plan.add(items[0], meal: "Lunch", station: "Grill")
        plan.add(items[0], meal: "Lunch", station: "Grill")
        plan.add(items[2], meal: "Dinner", station: "Grill")
        plan = try JSONDecoder().decode(MealPlan.self, from: JSONEncoder().encode(plan))
        XCTAssertEqual(MealPlan.total(.protein, in: plan.dishes).known, 30)
        XCTAssertEqual(MealPlan.total(.protein, in: plan.dishes).missing, 1)
        XCTAssertNil(MealPlan.total(.fat, in: plan.dishes).known)
        XCTAssertEqual(MealPlan.total(.fat, in: plan.dishes).missing, 3)
        plan.adjust(plan.dishes[0].id, by: -1)
        XCTAssertEqual(MealPlan.total(.protein, in: plan.dishes).known, 15)
        plan.adjust(plan.dishes[0].id, by: -1)
        XCTAssertNil(MealPlan.total(.protein, in: plan.dishes).known)
    }
}
