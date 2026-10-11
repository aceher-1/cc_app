import SwiftUI

@main
struct CommonsApp: App {
    @StateObject private var store = MenuStore()
    var body: some Scene {
        WindowGroup { MenuView().environmentObject(store).tint(CommonsTheme.red) }
    }
}
