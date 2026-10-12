#if DEBUG
import Foundation

// Deterministic UI-test data; never selected by release builds or normal launches.
struct TestMenuService: MenuFetching {
    func fetch(dateKey: String, now: Date) async throws -> DayMenu {
        let fixtures = #"[{"name":"Breakfast","groups":[{"name":"Test breakfast","items":[{"formalName":"Sample pancakes","ingredients":"Flour, water","allergens":[{"name":"Wheat"}],"isVegetarian":true}]}]},{"name":"Lunch","groups":[{"name":"Test station","items":[{"formalName":"Sample oatmeal","ingredients":"Oats, water, salt","allergens":[],"isVegan":true,"isVegetarian":true,"calories":"180"},{"formalName":"Sample bacon toast","ingredients":"Pork bacon, bread","allergens":[{"allergen":"WHEAT","name":"Wheat"}],"calories":"300"}]},{"name":"Test salad bar","items":[{"formalName":"Sample garden salad","ingredients":"Lettuce, tomato","allergens":[],"isVegan":true}]}]},{"name":"Dinner","groups":[{"name":"Test dinner","items":[{"formalName":"Sample baked tofu","ingredients":"Tofu, rice","allergens":[{"name":"Soy"}],"isVegan":true}]}]}]"#
        return try MenuParser.parse(Data(fixtures.utf8), dateKey: dateKey, fetchedAt: now)
    }
}
#endif
