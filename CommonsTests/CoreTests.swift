import XCTest
#if canImport(CommonsCore)
@testable import CommonsCore
#else
@testable import Commons
#endif

final class CoreTests: XCTestCase {
    private func item(_ ingredients: String? = "Potatoes, salt, vegetable oil", diets: Set<Diet> = [.vegan, .vegetarian],
                      name: String = "Test dish", allergens: Set<Allergen> = [], known: Bool = true,
                      unknown: [String] = []) -> MenuItem {
        MenuItem(id: "test", name: name, description: "", ingredients: ingredients, allergens: allergens,
                 unknownAllergens: unknown, hasAllergenData: known, diets: diets, calories: "100",
                 portion: nil, protein: nil, carbohydrates: nil, fat: nil)
    }

    func testHalalRequiresIngredientDataAndProviderPlantLabel() {
        XCTAssertEqual(HalalAssessment.assess(item()).status, .potentiallySuitable)
        XCTAssertEqual(HalalAssessment.assess(item(nil)).status, .needsConfirmation)
        XCTAssertEqual(HalalAssessment.assess(item("   ")).status, .needsConfirmation)
        XCTAssertEqual(HalalAssessment.assess(item(diets: [])).status, .needsConfirmation)
    }
    func testHalalChecksIngredientsEvenWhenSourceMarksDishVegan() {
        for ingredient in ["Pork", "Bacon", "Gelatin", "Vanilla extract (water, alcohol)", "Marsala wine", "Animal rennet"] {
            XCTAssertEqual(HalalAssessment.assess(item(ingredient)).status, .excluded, ingredient)
        }
        XCTAssertEqual(HalalAssessment.assess(item("Potatoes", name: "Bacon potatoes")).status, .excluded)
    }
    func testMeatAndSeafoodDoNotPassWithoutConfirmation() {
        for ingredient in ["Chicken, rice", "Beef stock", "Turkey broth", "Salmon, lemon", "Anchovies", "Shrimp"] {
            XCTAssertEqual(HalalAssessment.assess(item(ingredient)).status, .needsConfirmation, ingredient)
        }
        XCTAssertEqual(HalalAssessment.assess(item(allergens: [.fish])).status, .needsConfirmation)
    }
    func testWholeWordsAndVinegarAvoidMisleadingMatches() {
        XCTAssertEqual(HalalAssessment.assess(item("Graham crackers, white wine vinegar, butter")).status, .potentiallySuitable)
        XCTAssertEqual(HalalAssessment.assess(item("White wine vinegar, white wine")).status, .excluded)
        XCTAssertEqual(HalalAssessment.assess(item("Vegetable oil, cornmeal, red wine vinegar")).status, .potentiallySuitable)
    }
    func testDietAndAllergenFiltersIntersectAndUnknownDataDoesNotPass() {
        var preferences = DietaryPreferences(excludedAllergens: [.milk], requiredDiets: [.vegan, .mindful], halalPotentiallySuitable: true)
        XCTAssertTrue(preferences.includes(item(diets: [.vegan, .mindful])))
        XCTAssertFalse(preferences.includes(item(diets: [.vegan])))
        XCTAssertFalse(preferences.includes(item(diets: [.vegan, .mindful], allergens: [.milk])))
        XCTAssertFalse(preferences.includes(item(diets: [.vegan, .mindful], known: false)))
        XCTAssertFalse(preferences.includes(item(diets: [.vegan, .mindful], unknown: ["New source code"])))
        XCTAssertFalse(preferences.includes(item("Rum", diets: [.vegan, .mindful])))
        preferences = .init()
        XCTAssertTrue(preferences.includes(item(nil, known: false)))
    }
    func testPreferencesSurviveNewStorageInstance() throws {
        let suite = "CommonsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let chosen = DietaryPreferences(excludedAllergens: [.milk, .soy], requiredDiets: [.vegetarian], halalPotentiallySuitable: true)
        PreferenceStorage(defaults: defaults).save(chosen)
        XCTAssertEqual(PreferenceStorage(defaults: defaults).load(), chosen)
    }
    func testParserPreservesStationsLabelsAndUniqueIDs() throws {
        #if SWIFT_PACKAGE
        let url = try XCTUnwrap(Bundle.module.url(forResource: "menu", withExtension: "json", subdirectory: "Fixtures"))
        #else
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "menu", withExtension: "json"))
        #endif
        let menu = try MenuParser.parse(Data(contentsOf: url), dateKey: "2026-10-11", fetchedAt: Date())
        XCTAssertEqual(menu.meals.map(\.name), ["Breakfast", "Dinner"])
        XCTAssertEqual(menu.itemCount, 3)
        let items = menu.meals.flatMap(\.stations).flatMap(\.items)
        XCTAssertEqual(Set(items.map(\.id)).count, 3)
        XCTAssertEqual(items[0].allergens, [.soy, .treeNuts])
        XCTAssertTrue(items[0].diets.contains(.plantBased))
        XCTAssertEqual(items[1].calories, "90")
        XCTAssertFalse(items[2].hasAllergenData)
        XCTAssertNil(items[2].ingredients)
    }
    func testMalformedFeedDoesNotBecomeEmptyMenu() throws {
        for input in [#"{"error":"upstream failure"}"#, #"[{"name":"Dinner"}]"#, #"[{"name":"Dinner","groups":[{"name":"Grill","items":[{}]}]}]"#] {
            XCTAssertThrowsError(try MenuParser.parse(Data(input.utf8), dateKey: "2026-10-11", fetchedAt: Date()))
        }
        XCTAssertEqual(try MenuParser.parse(Data("[]".utf8), dateKey: "2026-10-11", fetchedAt: Date()).itemCount, 0)
    }
    func testRefreshBoundaryFollowsChicagoInsteadOfDeviceTimezone() throws {
        let utc = ISO8601DateFormatter()
        let before = try XCTUnwrap(utc.date(from: "2026-10-12T04:59:00Z"))
        let after = try XCTUnwrap(utc.date(from: "2026-10-12T05:01:00Z"))
        let menu = DayMenu(dateKey: "2026-10-11", fetchedAt: before, meals: [])
        XCTAssertEqual(DiningDay.key(for: before), "2026-10-11")
        XCTAssertEqual(DiningDay.key(for: after), "2026-10-12")
        XCTAssertTrue(DiningDay.isFresh(menu, now: before.addingTimeInterval(30)))
        XCTAssertFalse(DiningDay.isFresh(menu, now: after))
        XCTAssertNil(DiningDay.date(for: "2026-02-30"))
    }
    func testCacheRoundTripAndCorruptFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = DailyCache(directory: directory)
        let menu = DayMenu(dateKey: "2026-10-11", fetchedAt: Date(), meals: [])
        try cache.write(menu)
        XCTAssertEqual(DailyCache(directory: directory).read(menu.dateKey), menu)
        try Data("broken".utf8).write(to: directory.appendingPathComponent("2026-10-11.json"))
        XCTAssertNil(cache.read(menu.dateKey))
        XCTAssertNil(cache.read("../../other-file"))
    }
}
