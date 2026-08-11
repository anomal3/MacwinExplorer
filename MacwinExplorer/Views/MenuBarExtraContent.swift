import SwiftUI
import AppKit

extension Notification.Name {
    static let navigateToFavorite = Notification.Name("MacwinExplorer.navigateToFavorite")
}

/// Content of the optional menu-bar status item (Settings → "Значок в
/// строке меню"): quick access to favorites plus a way to fully quit —
/// useful once the app can also be summoned by the global hotkey.
struct MenuBarExtraContent: View {
    let favoritesStore: FavoritesStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if favoritesStore.items.isEmpty {
            Text("Нет избранного")
        } else {
            ForEach(favoritesStore.items) { item in
                Button(item.displayName) {
                    open(item.url)
                }
            }
        }
        Divider()
        Button("Новое окно") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }
        Divider()
        Button("Выход") {
            NSApplication.shared.terminate(nil)
        }
    }

    private func open(_ url: URL) {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "main")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NotificationCenter.default.post(name: .navigateToFavorite, object: url)
        }
    }
}
