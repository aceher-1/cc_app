import Foundation

enum DiningDay {
    // Menu dates and refresh boundaries always follow the dining hall, even while traveling.
    static var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(identifier: "America/Chicago")!
        return result
    }
    static func key(for date: Date) -> String {
        let values = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", values.year!, values.month!, values.day!)
    }
    static func date(for key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let result = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        guard let result, self.key(for: result) == key else { return nil }
        return result
    }
    static func dates(around now: Date = Date()) -> [Date] {
        let start = calendar.startOfDay(for: now)
        return (-1...14).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
    static func label(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    static func isFresh(_ menu: DayMenu, now: Date) -> Bool {
        key(for: menu.fetchedAt) == key(for: now) && menu.fetchedAt <= now
    }
}
