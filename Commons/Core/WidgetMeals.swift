import Foundation

struct MealHours: Codable {
    struct Window: Codable {
        let meal: String
        let start: String
        let end: String
    }
    let schemaVersion: Int
    let timezone: String
    let source: String
    let verifiedOn: String
    let validThrough: String
    let weekdays: [String: [Window]]
    // A present, empty override means confirmed closed. Missing dates use regular hours.
    let overrides: [String: [Window]]

    func windows(on day: String) -> [Window]? {
        guard schemaVersion == 1, timezone == "America/Chicago",
              let date = DiningDay.date(for: day), let verified = DiningDay.date(for: verifiedOn),
              let expiry = DiningDay.date(for: validThrough), verified <= date, date <= expiry else { return nil }
        let result = overrides[day] ?? weekdays[String(DiningDay.calendar.component(.weekday, from: date))]
        guard let result, result.allSatisfy({ window in
            guard let start = Self.date(window.start, on: day), let end = Self.date(window.end, on: day) else { return false }
            return !window.meal.isEmpty && start < end
        }) else { return nil }
        let sorted = result.sorted { $0.start < $1.start }
        for pair in zip(sorted, sorted.dropFirst()) where pair.0.end > pair.1.start { return nil }
        return sorted
    }

    static func date(_ time: String, on day: String) -> Date? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard time.count == 5, parts.count == 2, (0...23).contains(parts[0]), (0...59).contains(parts[1]),
              let date = DiningDay.date(for: day) else { return nil }
        return DiningDay.calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: date)
    }
}

struct WidgetMealCard {
    let dateKey: String
    let name: String
    let items: [String]
    let matchingCount: Int
    let totalCount: Int
    let startsAt: Date?
    let endsAt: Date?
    let url: URL
}

struct WidgetMealState {
    let current: WidgetMealCard?
    let next: WidgetMealCard?
    let hoursKnown: Bool
    let stale: Bool
    let filtersActive: Bool

    static func make(now: Date, menus: [DayMenu], hours: MealHours?, preferences: DietaryPreferences,
                     layout: MenuLayoutPreferences) -> WidgetMealState {
        let today = DiningDay.key(for: now)
        let calendar = DiningDay.calendar
        let weekday = calendar.component(.weekday, from: now)
        let todayMenu = menus.first { $0.dateKey == today }
        func card(_ meal: MenuMeal, in menu: DayMenu, start: Date? = nil, end: Date? = nil) -> WidgetMealCard {
            // Take one matching dish per station first, then fill remaining preview slots.
            let stations = layout.ordered(meal.stations).map { $0.items.filter(preferences.includes) }
            let matching = stations.flatMap { $0 }
            let ordered = stations.compactMap(\.first) + stations.flatMap { $0.dropFirst() }
            var seen = Set<String>()
            let names = ordered.compactMap { item -> String? in
                let key = item.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
                return seen.insert(key).inserted ? item.name : nil
            }
            var link = URLComponents()
            link.scheme = "msoedining"; link.host = "menu"
            link.queryItems = [URLQueryItem(name: "date", value: menu.dateKey), URLQueryItem(name: "meal", value: meal.name)]
            return WidgetMealCard(dateKey: menu.dateKey, name: meal.name, items: Array(names.prefix(3)),
                                  matchingCount: matching.count, totalCount: meal.itemCount, startsAt: start, endsAt: end, url: link.url!)
        }
        let stale = todayMenu.map { !DiningDay.isSourceFresh($0, now: now) } ?? false
        // Weekend brunch is shown all day, without inferred opening times or a countdown.
        if weekday == 1 || weekday == 7 {
            let brunch = todayMenu.flatMap { menu in
                menu.meals.first { $0.name.caseInsensitiveCompare("Brunch") == .orderedSame }.map { card($0, in: menu) }
            }
            return .init(current: brunch, next: nil, hoursKnown: false, stale: stale, filtersActive: preferences.count > 0)
        }
        let todayWindows = hours?.windows(on: today)
        var scheduled: [WidgetMealCard] = []
        for menu in menus where menu.dateKey >= today {
            for window in hours?.windows(on: menu.dateKey) ?? [] {
                guard let meal = menu.meals.first(where: { $0.name.caseInsensitiveCompare(window.meal) == .orderedSame }),
                      let start = MealHours.date(window.start, on: menu.dateKey),
                      let end = MealHours.date(window.end, on: menu.dateKey) else { continue }
                scheduled.append(card(meal, in: menu, start: start, end: end))
            }
        }
        scheduled.sort { $0.startsAt! < $1.startsAt! }
        let current = scheduled.first { $0.startsAt! <= now && now < $0.endsAt! }
        // Never claim a future meal is current when the dining hall is between services.
        let next = scheduled.first { $0.startsAt! > now }
        return .init(current: current, next: next, hoursKnown: todayWindows != nil, stale: stale,
                     filtersActive: preferences.count > 0)
    }
}

struct WidgetSettings: Codable {
    var preferences = DietaryPreferences()
    var layout = MenuLayoutPreferences()
}

struct WidgetStorage {
    static let groupID = "group.com.aceher.msoedining"
    static let kind = "DiningMeals"
    let directory: URL
    var cache: DailyCache { DailyCache(directory: directory.appendingPathComponent("menus")) }

    static var shared: WidgetStorage? {
        #if os(iOS)
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else { return nil }
        return WidgetStorage(directory: url.appendingPathComponent("WidgetData"))
        #else
        return nil
        #endif
    }
    func read<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    func write<T: Encodable>(_ value: T, named name: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: directory.appendingPathComponent(name), options: .atomic)
    }
}
