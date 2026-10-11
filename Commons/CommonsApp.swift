import SwiftUI

@main
struct CommonsApp: App {
    @StateObject private var store: MenuStore
    init() {
        #if DEBUG
        if CommandLine.arguments.contains("--ui-testing") {
            let defaults = UserDefaults(suiteName: "commons.uiTesting")!
            let cache = DailyCache(directory: DailyCache().directory.appendingPathComponent("UITesting"))
            if CommandLine.arguments.contains("--reset-preferences") {
                defaults.removePersistentDomain(forName: "commons.uiTesting")
                try? FileManager.default.removeItem(at: cache.directory)
            }
            _store = StateObject(wrappedValue: MenuStore(service: TestMenuService(), cache: cache, defaults: defaults))
            return
        }
        #endif
        _store = StateObject(wrappedValue: MenuStore())
    }
    var body: some Scene {
        WindowGroup { MenuView().environmentObject(store).tint(CommonsTheme.red) }
    }
}
