import XCTest
#if canImport(CommonsCore)
@testable import CommonsCore
#else
@testable import Commons
#endif

final class WidgetTests: XCTestCase {
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private func hours(overrides: [String: [MealHours.Window]] = [:]) -> MealHours {
        let windows = [MealHours.Window(meal: "Breakfast", start: "07:00", end: "10:00"),
                       .init(meal: "Lunch", start: "11:00", end: "14:00"),
                       .init(meal: "Dinner", start: "16:00", end: "20:30")]
        return MealHours(schemaVersion: 1, timezone: "America/Chicago", source: "test", verifiedOn: "2026-10-19",
                         validThrough: "2026-11-18", weekdays: ["2": windows, "3": windows, "6": windows], overrides: overrides)
    }
    private func menu(_ day: String, names: [String] = ["Breakfast", "Lunch", "Dinner"]) -> DayMenu {
        let first = MenuItem(id: "1", name: "Milk toast", description: "", ingredients: "Milk, bread",
                             allergens: [.milk], unknownAllergens: [], hasAllergenData: true, diets: [.vegetarian],
                             calories: nil, portion: nil, protein: nil, carbohydrates: nil, fat: nil)
        let second = MenuItem(id: "2", name: "Rice", description: "", ingredients: "Rice, water",
                              allergens: [], unknownAllergens: [], hasAllergenData: true, diets: [.vegan],
                              calories: nil, portion: nil, protein: nil, carbohydrates: nil, fat: nil)
        return DayMenu(dateKey: day, fetchedAt: date(day + "T10:00:00Z"), meals: names.map {
            MenuMeal(id: $0, name: $0, stations: [.init(id: "a", name: "Savory", items: [first]),
                                                .init(id: "b", name: "Grown", items: [second])])
        })
    }
    private func state(_ instant: String, menus: [DayMenu]? = nil, schedule: MealHours? = nil,
                       preferences: DietaryPreferences = .init(), layout: MenuLayoutPreferences = .init()) -> WidgetMealState {
        .make(now: date(instant), menus: menus ?? [menu("2026-10-19"), menu("2026-10-20")],
              hours: schedule ?? hours(), preferences: preferences, layout: layout)
    }
    func testMealBoundariesAndGapsUseDiningHallTimezone() {
        XCTAssertEqual(state("2026-10-19T13:00:00Z").current?.name, "Breakfast") // 8 a.m. Chicago
        let gap = state("2026-10-19T15:00:00Z") // Breakfast ends at exactly 10.
        XCTAssertNil(gap.current)
        XCTAssertEqual(gap.next?.name, "Lunch")
        XCTAssertEqual(state("2026-10-19T16:00:00Z").current?.name, "Lunch")
        let night = state("2026-10-20T02:00:00Z") // 9 p.m. Monday, next breakfast Tuesday.
        XCTAssertNil(night.current)
        XCTAssertEqual(night.next?.dateKey, "2026-10-20")
        XCTAssertEqual(night.next?.name, "Breakfast")
    }
    func testWeekendOnlyShowsBrunchWithoutTimer() {
        let result = state("2026-10-24T14:00:00Z", menus: [menu("2026-10-24", names: ["Breakfast", "Brunch"])])
        XCTAssertEqual(result.current?.name, "Brunch")
        XCTAssertNil(result.current?.startsAt)
        XCTAssertNil(result.next)
        XCTAssertFalse(result.hoursKnown)
    }
    func testFiltersAndOrderMatchAppAndAllFilteredRemainsVisible() {
        var prefs = DietaryPreferences(excludedAllergens: [.milk])
        let filtered = state("2026-10-19T17:00:00Z", preferences: prefs)
        XCTAssertEqual(filtered.current?.items, ["Rice"])
        XCTAssertEqual(filtered.current?.matchingCount, 1)
        XCTAssertEqual(filtered.current?.totalCount, 2)
        prefs.requiredDiets = [.mindful]
        XCTAssertEqual(state("2026-10-19T17:00:00Z", preferences: prefs).current?.matchingCount, 0)
        let layout = MenuLayoutPreferences(sectionOrder: ["grown", "savory"])
        XCTAssertEqual(state("2026-10-19T17:00:00Z", layout: layout).current?.items.first, "Rice")
    }
    func testExpiredHoursClosedOverridesAndMissingMenusNeverInventService() {
        XCTAssertNil(hours().windows(on: "2026-11-19"))
        let closed = state("2026-10-19T17:00:00Z", schedule: hours(overrides: ["2026-10-19": []]))
        XCTAssertNil(closed.current)
        XCTAssertEqual(closed.next?.dateKey, "2026-10-20")
        XCTAssertTrue(closed.hoursKnown)
        let absent = state("2026-10-19T17:00:00Z", menus: [])
        XCTAssertNil(absent.current)
        XCTAssertNil(absent.next)
        let missingHours = WidgetMealState.make(now: date("2026-10-19T17:00:00Z"), menus: [menu("2026-10-19")],
                                               hours: nil, preferences: .init(), layout: .init())
        XCTAssertFalse(missingHours.hoursKnown)
        XCTAssertNil(missingHours.current)
    }
    func testDSTClockAndStaleMenus() {
        XCTAssertEqual(MealHours.date("07:00", on: "2026-11-02"), date("2026-11-02T13:00:00Z"))
        XCTAssertNil(MealHours.date("25:00", on: "2026-10-19"))
        let old = DayMenu(dateKey: "2026-10-19", fetchedAt: date("2026-10-18T10:00:00Z"), meals: menu("2026-10-19").meals)
        XCTAssertTrue(state("2026-10-19T17:00:00Z", menus: [old]).stale)
        let parts = URLComponents(url: state("2026-10-19T17:00:00Z").current!.url, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(parts.queryItems?.first(where: { $0.name == "meal" })?.value, "Lunch")
    }
    func testSharedSettingsRoundTripAndCachePruning() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = WidgetStorage(directory: directory)
        let settings = WidgetSettings(preferences: .init(halalPotentiallySuitable: true), layout: .init())
        try storage.write(settings, named: "settings.json")
        XCTAssertTrue(storage.read("settings.json", as: WidgetSettings.self)!.preferences.halalPotentiallySuitable)
        try storage.cache.write(menu("2026-10-19"))
        XCTAssertEqual(storage.cache.read("2026-10-19")?.itemCount, 6)
        storage.cache.prune(now: date("2026-12-01T12:00:00Z"))
        XCTAssertNil(storage.cache.read("2026-10-19"))
    }
}
