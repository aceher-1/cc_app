import SwiftUI
import WidgetKit

struct DiningEntry: TimelineEntry {
    let date: Date
    let meals: WidgetMealState
    var needsSetup = false
}

struct DiningProvider: TimelineProvider {
    func placeholder(in context: Context) -> DiningEntry {
        let now = Date()
        let lunch = WidgetMealCard(dateKey: DiningDay.key(for: now), name: "Lunch",
                                  items: ["Roasted vegetables", "Rice bowl", "Garden salad"],
                                  matchingCount: 8, totalCount: 12, startsAt: now.addingTimeInterval(-3600),
                                  endsAt: now.addingTimeInterval(3600), url: URL(string: "msoedining://menu")!)
        let dinner = WidgetMealCard(dateKey: DiningDay.key(for: now), name: "Dinner", items: ["Pasta", "Vegetable soup"],
                                   matchingCount: 6, totalCount: 10, startsAt: now.addingTimeInterval(7200),
                                   endsAt: now.addingTimeInterval(14400), url: URL(string: "msoedining://menu")!)
        return DiningEntry(date: now, meals: .init(current: lunch, next: dinner, hoursKnown: true, stale: false, filtersActive: false))
    }

    func getSnapshot(in context: Context, completion: @escaping (DiningEntry) -> Void) {
        if context.isPreview { completion(placeholder(in: context)); return }
        completion(entries(now: Date()).first!)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DiningEntry>) -> Void) {
        Task {
            let now = Date()
            await refresh(now: now)
            // Explicit entries handle meal starts/ends and midnight without constant downloads.
            completion(Timeline(entries: entries(now: now), policy: .after(now.addingTimeInterval(3600))))
        }
    }

    private func refresh(now: Date) async {
        guard let storage = WidgetStorage.shared else { return }
        let lastAttempt = storage.read("last-attempt.json", as: Date.self)
        guard lastAttempt.map({ now.timeIntervalSince($0) >= 900 }) ?? true else { return }
        try? storage.write(now, named: "last-attempt.json")
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 10
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let service = SharedMenuService(session: session)
        for offset in 0...1 {
            guard let day = DiningDay.calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            let key = DiningDay.key(for: day)
            if let saved = storage.cache.read(key), DiningDay.isFresh(saved, now: now),
               DiningDay.isSourceFresh(saved, now: now) { continue }
            if let menu = try? await service.fetch(dateKey: key, now: now) { try? storage.cache.write(menu) }
        }
        let hoursChecked = storage.read("hours-checked.json", as: Date.self)
        if hoursChecked.map({ DiningDay.key(for: $0) != DiningDay.key(for: now) }) ?? true {
            let url = URL(string: "https://aceher-1.github.io/cc_app/meal-hours.json")!
            if let (data, response) = try? await session.data(from: url),
               (response as? HTTPURLResponse)?.statusCode == 200,
               let hours = try? JSONDecoder().decode(MealHours.self, from: data),
               hours.schemaVersion == 1, hours.timezone == "America/Chicago" {
                try? storage.write(hours, named: "hours.json")
                try? storage.write(now, named: "hours-checked.json")
            }
        }
        storage.cache.prune(now: now)
    }

    private func entries(now: Date) -> [DiningEntry] {
        guard let storage = WidgetStorage.shared else {
            return [DiningEntry(date: now, meals: .init(current: nil, next: nil, hoursKnown: false,
                                                       stale: false, filtersActive: false), needsSetup: true)]
        }
        let settings = storage.read("settings.json", as: WidgetSettings.self) ?? WidgetSettings()
        let hours = storage.read("hours.json", as: MealHours.self)
        let menus = (0...1).compactMap { offset -> DayMenu? in
            guard let date = DiningDay.calendar.date(byAdding: .day, value: offset, to: now) else { return nil }
            return storage.cache.read(DiningDay.key(for: date))
        }
        let midnight = DiningDay.calendar.date(byAdding: .day, value: 1, to: DiningDay.calendar.startOfDay(for: now))!
        var dates: Set<Date> = [now, midnight]
        for menu in menus {
            for window in hours?.windows(on: menu.dateKey) ?? [] {
                for time in [window.start, window.end] {
                    if let date = MealHours.date(time, on: menu.dateKey), date > now { dates.insert(date) }
                }
            }
        }
        return dates.sorted().map { date in
            DiningEntry(date: date, meals: .make(now: date, menus: menus, hours: hours,
                                               preferences: settings.preferences, layout: settings.layout))
        }
    }
}

struct DiningWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: DiningEntry
    private let red = Color(red: 0.8, green: 0, blue: 0.18)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("MSOE DINING", systemImage: "fork.knife").font(.system(size: 10, weight: .heavy))
                Spacer(minLength: 0)
                if entry.meals.filtersActive { Image(systemName: "line.3.horizontal.decrease").font(.caption2).accessibilityLabel("Dietary filters applied") }
            }
            if entry.needsSetup {
                Text("Open MSOE Dining").font(.headline)
                Text("Widget sharing is unavailable.").font(.caption)
            } else if family == .systemMedium && entry.meals.hoursKnown {
                HStack(alignment: .top, spacing: 12) {
                    Link(destination: entry.meals.current?.url ?? URL(string: "msoedining://menu")!) {
                        mealColumn(entry.meals.current, label: entry.meals.hoursKnown ? "NOW" : "TODAY")
                    }
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1)
                    Link(destination: entry.meals.next?.url ?? URL(string: "msoedining://menu")!) {
                        mealColumn(entry.meals.next, label: "NEXT")
                    }
                }.frame(maxHeight: .infinity, alignment: .top)
                countdown
            } else {
                mealColumn(entry.meals.current ?? entry.meals.next,
                           label: entry.meals.current != nil ? (entry.meals.hoursKnown ? "NOW" : "TODAY") : "NEXT")
                Spacer(minLength: 0)
                countdown
            }
            if entry.meals.stale { Text("Saved menu · may be outdated").font(.system(size: 9)).foregroundStyle(.white.opacity(0.8)) }
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) {
            if renderingMode == .fullColor {
                LinearGradient(colors: [Color(white: 0.075), red.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
            } else { Color.clear }
        }
        .widgetURL((entry.meals.current ?? entry.meals.next)?.url ?? URL(string: "msoedining://menu"))
    }

    private func mealColumn(_ meal: WidgetMealCard?, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.75))
            if let meal {
                Text(meal.name).font(.headline).lineLimit(1).minimumScaleFactor(0.8)
                if meal.items.isEmpty {
                    Text(meal.totalCount == 0 ? "Menu not posted" : "No matching options").font(.caption).lineLimit(2)
                } else {
                    ForEach(Array(meal.items.prefix(family == .systemSmall ? 2 : 3).enumerated()), id: \.offset) { _, name in
                        Text(name).font(.system(size: 11)).lineLimit(1)
                    }
                    Text("\(meal.matchingCount) options\(entry.meals.filtersActive ? " · filtered" : "")")
                        .font(.system(size: 9)).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
                }
            } else {
                Text(entry.meals.hoursKnown ? (label == "NOW" ? "No current menu" : "Not posted") : "Hours unavailable")
                    .font(.caption).lineLimit(2)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var countdown: some View {
        if entry.meals.hoursKnown, let next = entry.meals.next, let start = next.startsAt, start > entry.date {
            HStack(spacing: 4) {
                Text("\(next.name) in").lineLimit(1)
                Text(timerInterval: entry.date...start, countsDown: true).monospacedDigit()
                    .multilineTextAlignment(.leading)
            }.font(.system(size: 10, weight: .semibold))
            Text("Scheduled · Milwaukee time").font(.system(size: 8)).foregroundStyle(.white.opacity(0.7))
        } else {
            Text("Hours unavailable").font(.system(size: 10, weight: .semibold))
        }
    }
}

@main
struct DiningWidgets: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetStorage.kind, provider: DiningProvider()) { entry in DiningWidgetView(entry: entry) }
            .configurationDisplayName("Dining Meals")
            .description("Current and next menus with your dietary filters and scheduled meal countdowns.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
