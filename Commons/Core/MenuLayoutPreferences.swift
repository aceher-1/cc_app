import Foundation

struct MenuLayoutPreferences: Codable, Equatable {
    var sectionOrder: [String] = []
    var collapsedSections: Set<String> = []

    // Source IDs contain the date and position. Names preserve the user's layout across snapshots.
    static func key(for name: String) -> String {
        name.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    func ordered(_ stations: [MenuStation]) -> [MenuStation] {
        var ranks: [String: Int] = [:]
        for (index, key) in sectionOrder.enumerated() where ranks[key] == nil { ranks[key] = index }
        return stations.enumerated().sorted { left, right in
            let a = ranks[Self.key(for: left.element.name)] ?? Int.max
            let b = ranks[Self.key(for: right.element.name)] ?? Int.max
            return a == b ? left.offset < right.offset : a < b
        }.map(\.element)
    }

    func isCollapsed(_ name: String) -> Bool { collapsedSections.contains(Self.key(for: name)) }

    mutating func setCollapsed(_ collapsed: Bool, for name: String) {
        let key = Self.key(for: name)
        if collapsed { collapsedSections.insert(key) }
        else { collapsedSections.remove(key) }
    }

    mutating func moveSections(_ names: [String], from offsets: IndexSet, to destination: Int) {
        var keys = names.map(Self.key(for:))
        guard !offsets.isEmpty, offsets.allSatisfy({ keys.indices.contains($0) }),
              (0...keys.count).contains(destination), Set(keys).count == keys.count else { return }
        let moving = offsets.map { keys[$0] }
        for index in offsets.reversed() { keys.remove(at: index) }
        let insertion = destination - offsets.filter { $0 < destination }.count
        keys.insert(contentsOf: moving, at: insertion)
        // Keep saved sections absent from this meal, so switching meals never forgets their order.
        let present = Set(keys)
        sectionOrder = keys + sectionOrder.filter { !present.contains($0) }
    }
}

struct MenuLayoutStorage {
    let defaults: UserDefaults
    private let key = "commons.menuLayout.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() -> MenuLayoutPreferences {
        guard let data = defaults.data(forKey: key),
              let result = try? JSONDecoder().decode(MenuLayoutPreferences.self, from: data) else { return .init() }
        return result
    }
    func save(_ preferences: MenuLayoutPreferences) {
        if let data = try? JSONEncoder().encode(preferences) { defaults.set(data, forKey: key) }
    }
}
