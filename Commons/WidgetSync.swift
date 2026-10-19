import Foundation
import WidgetKit

enum WidgetSync {
    static func settings(_ preferences: DietaryPreferences, layout: MenuLayoutPreferences) {
        guard let storage = WidgetStorage.shared else { return }
        let value = WidgetSettings(preferences: preferences, layout: layout)
        guard let data = try? JSONEncoder().encode(value),
              data != (try? Data(contentsOf: storage.directory.appendingPathComponent("settings.json"))) else { return }
        do {
            try storage.write(value, named: "settings.json")
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetStorage.kind)
        } catch { /* Keep app settings usable if the shared container is unavailable. */ }
    }
    static func menu(_ menu: DayMenu) {
        guard let storage = WidgetStorage.shared else { return }
        do {
            try storage.cache.write(menu)
            storage.cache.prune(now: Date())
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetStorage.kind)
        } catch { /* The widget can download the shared feed independently. */ }
    }
}
