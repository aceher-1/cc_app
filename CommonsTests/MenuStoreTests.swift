import XCTest
@testable import Commons

private actor StubMenuService: MenuFetching {
    private(set) var calls = 0
    var fail = false
    func setFail(_ value: Bool) { fail = value }
    func fetch(dateKey: String, now: Date) async throws -> DayMenu {
        calls += 1
        if fail { throw URLError(.notConnectedToInternet) }
        return DayMenu(dateKey: dateKey, fetchedAt: now, meals: [])
    }
}

@MainActor
final class MenuStoreTests: XCTestCase {
    func testChangingFilterFieldsPersistsAcrossStoreInstances() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "CommonsPreferenceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { try? FileManager.default.removeItem(at: directory); defaults.removePersistentDomain(forName: suite) }
        let service = StubMenuService()
        let cache = DailyCache(directory: directory)
        let store = MenuStore(service: service, cache: cache, defaults: defaults)
        store.preferences.excludedAllergens.insert(.milk)
        store.preferences.requiredDiets.insert(.vegan)
        store.preferences.halalPotentiallySuitable = true
        let restarted = MenuStore(service: service, cache: cache, defaults: defaults)
        XCTAssertEqual(restarted.preferences, store.preferences)
        XCTAssertEqual(restarted.preferences.count, 3)
    }

    func testDailyReuseRestartRolloverAndManualRefresh() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "CommonsStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { try? FileManager.default.removeItem(at: directory); defaults.removePersistentDomain(forName: suite) }
        let cache = DailyCache(directory: directory)
        let service = StubMenuService()
        let store = MenuStore(service: service, cache: cache, defaults: defaults)
        let now = Date()
        await store.load(now: now)
        await store.load(now: now.addingTimeInterval(60))
        var calls = await service.calls
        XCTAssertEqual(calls, 1)
        let restarted = MenuStore(service: service, cache: cache, defaults: defaults)
        await restarted.load(now: now.addingTimeInterval(120))
        calls = await service.calls
        XCTAssertEqual(calls, 1)
        await restarted.load(force: true, now: now.addingTimeInterval(180))
        calls = await service.calls
        XCTAssertEqual(calls, 2)
        let nextDay = try XCTUnwrap(DiningDay.calendar.date(byAdding: .day, value: 1, to: now))
        await restarted.foreground(now: nextDay)
        calls = await service.calls
        XCTAssertEqual(calls, 3)
        XCTAssertEqual(restarted.selectedDateKey, DiningDay.key(for: nextDay))
    }
    func testOfflineFailurePreservesCacheAndThrottlesAutomaticRetries() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "CommonsOfflineTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { try? FileManager.default.removeItem(at: directory); defaults.removePersistentDomain(forName: suite) }
        let now = Date()
        let yesterday = try XCTUnwrap(DiningDay.calendar.date(byAdding: .day, value: -1, to: now))
        let cache = DailyCache(directory: directory)
        let saved = DayMenu(dateKey: DiningDay.key(for: now), fetchedAt: yesterday, meals: [])
        try cache.write(saved)
        let service = StubMenuService()
        await service.setFail(true)
        let store = MenuStore(service: service, cache: cache, defaults: defaults)
        await store.load(now: now)
        await store.load(now: now.addingTimeInterval(60))
        let restarted = MenuStore(service: service, cache: cache, defaults: defaults)
        await restarted.load(now: now.addingTimeInterval(120))
        var calls = await service.calls
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(store.currentMenu, saved)
        XCTAssertNotNil(store.message)
        await restarted.load(force: true, now: now.addingTimeInterval(180))
        calls = await service.calls
        XCTAssertEqual(calls, 2)
    }
    func testSharedFeedPreservesSourceTimestampAndRejectsWrongDate() throws {
        let data = Data(#"{"schemaVersion":1,"date":"2026-10-11","updatedAt":"2026-10-11T09:23:00Z","meals":[]}"#.utf8)
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-12T15:00:00Z"))
        let menu = try SharedMenuService.decode(data, dateKey: "2026-10-11", checkedAt: now)
        XCTAssertEqual(menu.checkedAt, now)
        XCTAssertTrue(DiningDay.isFresh(menu, now: now))
        XCTAssertFalse(DiningDay.isSourceFresh(menu, now: now))
        XCTAssertThrowsError(try SharedMenuService.decode(data, dateKey: "2026-10-12", checkedAt: now))
        XCTAssertThrowsError(try SharedMenuService.decode(Data("[]".utf8), dateKey: "2026-10-11", checkedAt: now))
    }
}
