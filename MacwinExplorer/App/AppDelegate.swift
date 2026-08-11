import AppKit

/// Hosts the Cmd+Q confirmation (SwiftUI's App has no direct hook for
/// applicationShouldTerminate) and owns the global new-window hotkey and the
/// optional menu-bar status item's window-activation glue.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [SettingsKeys.confirmBeforeQuit: true])
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard UserDefaults.standard.bool(forKey: SettingsKeys.confirmBeforeQuit) else {
            return .terminateNow
        }
        let alert = NSAlert()
        alert.messageText = "Закрыть MacwinExplorer?"
        alert.informativeText = "Все открытые окна будут закрыты."
        alert.addButton(withTitle: "Закрыть")
        alert.addButton(withTitle: "Отмена")
        alert.alertStyle = .warning
        let response = alert.runModal()
        return response == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        GlobalHotKeyService.shared.applySavedShortcut()
    }
}
