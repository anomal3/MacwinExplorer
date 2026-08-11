import SwiftUI

@main
struct MacwinExplorerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(SettingsKeys.showMenuBarIcon) private var showMenuBarIcon = false
    @State private var favoritesStore = FavoritesStore()
    @State private var networkSharesStore = NetworkSharesStore()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(favoritesStore: favoritesStore, networkSharesStore: networkSharesStore)
                .frame(minWidth: 820, minHeight: 520)
        }
        .defaultSize(width: 1000, height: 640)

        Settings {
            SettingsView(networkSharesStore: networkSharesStore)
        }

        MenuBarExtra("MacwinExplorer", systemImage: "folder", isInserted: $showMenuBarIcon) {
            MenuBarExtraContent(favoritesStore: favoritesStore)
        }
    }
}
