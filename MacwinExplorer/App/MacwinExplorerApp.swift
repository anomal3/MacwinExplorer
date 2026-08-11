import SwiftUI

@main
struct MacwinExplorerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 820, minHeight: 520)
        }
        .defaultSize(width: 1000, height: 640)

        Settings {
            SettingsView()
        }
    }
}
