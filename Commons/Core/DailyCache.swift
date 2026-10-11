import Foundation

struct DailyCache {
    let directory: URL
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CommonsMenuCache", isDirectory: true)
    }
    func read(_ dateKey: String) -> DayMenu? {
        guard DiningDay.date(for: dateKey) != nil,
              let data = try? Data(contentsOf: file(dateKey)),
              let menu = try? JSONDecoder().decode(DayMenu.self, from: data), menu.dateKey == dateKey else { return nil }
        return menu
    }
    func write(_ menu: DayMenu) throws {
        guard DiningDay.date(for: menu.dateKey) != nil else { throw MenuParseError.changedFormat }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(menu).write(to: file(menu.dateKey), options: .atomic)
    }
    func prune(now: Date) {
        let cutoff = DiningDay.calendar.date(byAdding: .day, value: -30, to: now)!
        for url in (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [] {
            let key = url.deletingPathExtension().lastPathComponent
            if let date = DiningDay.date(for: key), date < cutoff { try? FileManager.default.removeItem(at: url) }
        }
    }
    private func file(_ key: String) -> URL { directory.appendingPathComponent("\(key).json") }
}
