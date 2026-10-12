import XCTest
#if SWIFT_PACKAGE
@testable import CommonsCore
#else
@testable import Commons
#endif

final class MenuLayoutTests: XCTestCase {
    private func stations(_ names: [String]) -> [MenuStation] {
        names.enumerated().map { MenuStation(id: "source/\($0.offset)", name: $0.element, items: []) }
    }

    func testOrderingUsesNamesAcrossSnapshotsAndKeepsUnknownSections() {
        let layout = MenuLayoutPreferences(sectionOrder: ["salad bar", "grill"])
        let source = stations(["Grill", "New station", " SALAD  BAR ", "Grill"])
        XCTAssertEqual(layout.ordered(source).map(\.name), [" SALAD  BAR ", "Grill", "Grill", "New station"])
        XCTAssertEqual(layout.ordered(source).map(\.id), ["source/2", "source/0", "source/3", "source/1"])
    }

    func testMovingSectionsUpDownAndTogetherPreservesAbsentSections() {
        var layout = MenuLayoutPreferences(sectionOrder: ["grill", "salad", "bakery", "dinner only"])
        layout.moveSections(["Grill", "Salad", "Bakery"], from: IndexSet(integer: 2), to: 0)
        XCTAssertEqual(layout.sectionOrder, ["bakery", "grill", "salad", "dinner only"])
        layout.moveSections(["Bakery", "Grill", "Salad"], from: IndexSet(integer: 0), to: 3)
        XCTAssertEqual(layout.sectionOrder, ["grill", "salad", "bakery", "dinner only"])
        layout.moveSections(["Grill", "Salad", "Bakery"], from: IndexSet([0, 1]), to: 3)
        XCTAssertEqual(layout.sectionOrder, ["bakery", "grill", "salad", "dinner only"])
        let saved = layout
        layout.moveSections(["Grill"], from: IndexSet(integer: 8), to: 0)
        XCTAssertEqual(layout, saved)
    }

    func testLayoutPersistsIndependentlyOfDietaryPreferences() throws {
        let suite = "CommonsLayoutTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let diet = DietaryPreferences(excludedAllergens: [.milk], halalPotentiallySuitable: true)
        PreferenceStorage(defaults: defaults).save(diet)
        var layout = MenuLayoutPreferences(sectionOrder: ["salad", "grill"])
        layout.setCollapsed(true, for: " GRILL ")
        MenuLayoutStorage(defaults: defaults).save(layout)
        let restored = MenuLayoutStorage(defaults: defaults).load()
        XCTAssertEqual(restored, layout)
        XCTAssertTrue(restored.isCollapsed("Grill"))
        MenuLayoutStorage(defaults: defaults).save(.init())
        XCTAssertEqual(MenuLayoutStorage(defaults: defaults).load(), .init())
        XCTAssertEqual(PreferenceStorage(defaults: defaults).load(), diet)
    }
}
