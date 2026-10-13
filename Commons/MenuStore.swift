import Foundation
import Combine

@MainActor
final class MenuStore: ObservableObject {
    @Published var preferences: DietaryPreferences { didSet { preferenceStorage.save(preferences) } }
    @Published var layout: MenuLayoutPreferences { didSet { layoutStorage.save(layout) } }
    @Published var selectedDateKey: String
    @Published var selectedMealName = ""
    @Published var searchText = ""
    @Published private(set) var menus: [String: DayMenu] = [:]
    @Published private(set) var loadingDates: Set<String> = []
    @Published private(set) var messages: [String: String] = [:]
    @Published private(set) var dates = DiningDay.dates()
    private let preferenceStorage: PreferenceStorage
    private let layoutStorage: MenuLayoutStorage
    private let cache: DailyCache
    private let service: any MenuFetching
    private let defaults: UserDefaults
    private var lastTodayKey: String

    init(service: any MenuFetching = SharedMenuService(), cache: DailyCache = DailyCache(), defaults: UserDefaults = .standard) {
        self.service = service
        self.cache = cache
        self.defaults = defaults
        preferenceStorage = PreferenceStorage(defaults: defaults)
        layoutStorage = MenuLayoutStorage(defaults: defaults)
        preferences = preferenceStorage.load()
        layout = layoutStorage.load()
        let today = DiningDay.key(for: Date())
        selectedDateKey = today
        lastTodayKey = today
        if let saved = cache.read(today) { menus[today] = saved }
        cache.prune(now: Date())
    }

    var currentMenu: DayMenu? { menus[selectedDateKey] }
    var isLoading: Bool { loadingDates.contains(selectedDateKey) }
    var message: String? { messages[selectedDateKey] }
    var selectedDate: Date { DiningDay.date(for: selectedDateKey) ?? Date() }
    var currentMeal: MenuMeal? {
        guard let meals = currentMenu?.meals, !meals.isEmpty else { return nil }
        if let match = meals.first(where: { $0.name == selectedMealName }) { return match }
        if selectedDateKey == DiningDay.key(for: Date()) {
            let hour = DiningDay.calendar.component(.hour, from: Date())
            let preferred = hour < 10 ? ["Breakfast", "Brunch"] : hour < 15 ? ["Lunch", "Brunch"] : ["Dinner", "Supper"]
            for name in preferred {
                if let meal = meals.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) { return meal }
            }
        }
        return meals.first
    }
    var visibleStations: [MenuStation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching: [MenuStation] = (currentMeal?.stations ?? []).compactMap { station in
            let items = station.items.filter { item in
                preferences.includes(item) && (query.isEmpty || item.name.localizedCaseInsensitiveContains(query)
                    || item.description.localizedCaseInsensitiveContains(query) || station.name.localizedCaseInsensitiveContains(query))
            }
            return items.isEmpty ? nil : MenuStation(id: station.id, name: station.name, items: items)
        }
        return layout.ordered(matching)
    }
    var visibleCount: Int { visibleStations.reduce(0) { $0 + $1.items.count } }

    // Keep stations whose search results are all excluded so their hidden dishes remain inspectable.
    var searchedStations: [MenuStation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return layout.ordered((currentMeal?.stations ?? []).compactMap { station in
            let items = station.items.filter { item in
                query.isEmpty || item.name.localizedCaseInsensitiveContains(query)
                    || item.description.localizedCaseInsensitiveContains(query)
                    || station.name.localizedCaseInsensitiveContains(query)
            }
            return items.isEmpty ? nil : MenuStation(id: station.id, name: station.name, items: items)
        })
    }

    var currentMealIndex: Int? {
        guard let meal = currentMeal else { return nil }
        return currentMenu?.meals.firstIndex(where: { $0.id == meal.id })
    }
    var sectionNames: [String] {
        var seen: Set<String> = []
        return layout.ordered(currentMeal?.stations ?? []).compactMap { station in
            seen.insert(MenuLayoutPreferences.key(for: station.name)).inserted ? station.name : nil
        }
    }
    @discardableResult func selectMeal(named name: String) -> Bool {
        guard currentMenu?.meals.contains(where: { $0.name == name }) == true else { return false }
        selectedMealName = name
        return true
    }
    @discardableResult func selectAdjacentMeal(_ direction: Int) -> Bool {
        guard direction == -1 || direction == 1, let index = currentMealIndex,
              let meals = currentMenu?.meals, meals.indices.contains(index + direction) else { return false }
        selectedMealName = meals[index + direction].name
        return true
    }
    func moveSections(from offsets: IndexSet, to destination: Int) {
        layout.moveSections(sectionNames, from: offsets, to: destination)
    }

    func foreground(now: Date = Date()) async {
        let today = DiningDay.key(for: now)
        if lastTodayKey != today {
            if selectedDateKey == lastTodayKey { selectedDateKey = today; selectedMealName = "" }
            lastTodayKey = today
            dates = DiningDay.dates(around: now)
            cache.prune(now: now)
        }
        await load(now: now)
    }

    func load(force: Bool = false, now: Date = Date()) async {
        let key = selectedDateKey
        if menus[key] == nil, let saved = cache.read(key) { menus[key] = saved }
        guard !loadingDates.contains(key) else { return }
        if !force, let saved = menus[key], DiningDay.isFresh(saved, now: now) {
            // An early opening before the daily server job must not pin yesterday's snapshot all day.
            if DiningDay.isSourceFresh(saved, now: now)
                || now.timeIntervalSince(saved.checkedAt ?? saved.fetchedAt) < 3600 { return }
        }
        let attemptKey = "commons.lastAttempt.\(key)"
        if !force, let attempt = defaults.object(forKey: attemptKey) as? Date, now.timeIntervalSince(attempt) < 300 {
            if messages[key] == nil { messages[key] = "The last refresh did not finish. Retry manually or wait a few minutes." }
            return
        }
        loadingDates.insert(key)
        messages[key] = nil
        defaults.set(now, forKey: attemptKey)
        defer { loadingDates.remove(key) }
        do {
            let menu = try await service.fetch(dateKey: key, now: now)
            menus[key] = menu
            if !DiningDay.isSourceFresh(menu, now: now) {
                messages[key] = "The shared menu has not updated today. Showing its latest published version."
            }
            do { try cache.write(menu) }
            catch { messages[key] = "Menu loaded, but could not be saved for offline use." }
        } catch is CancellationError {
            // A date switch may cancel the old view task; don't throttle a canceled attempt.
            defaults.removeObject(forKey: attemptKey)
        } catch let error as URLError where error.code == .cancelled {
            defaults.removeObject(forKey: attemptKey)
        } catch {
            let detail = (error as? LocalizedError)?.errorDescription ?? "Unable to connect to the shared menu service."
            messages[key] = menus[key] == nil ? detail : "Showing the saved menu. \(detail)"
        }
    }
}
