#if DEBUG
import Foundation

// Deterministic UI-test data; never selected by release builds or normal launches.
struct TestMenuService: MenuFetching {
    func fetch(dateKey: String, now: Date) async throws -> DayMenu {
        let fixtures = #"[{"name":"Lunch","groups":[{"name":"Test station","items":[{"formalName":"Sample oatmeal","ingredients":"Oats, water, salt","allergens":[],"isVegan":true,"isVegetarian":true,"calories":"180"},{"formalName":"Sample bacon toast","ingredients":"Pork bacon, bread","allergens":[{"allergen":"WHEAT","name":"Wheat"}],"calories":"300"}]}]}]"#
        return try MenuParser.parse(Data(fixtures.utf8), dateKey: dateKey, fetchedAt: now)
    }
}
#endif
