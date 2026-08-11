import Foundation
import ServiceManagement

/// Registers/unregisters MacwinExplorer as a login item — used so saved
/// network shares flagged "auto-connect at login" actually get reconnected
/// (the app needs to launch at login to do that).
enum LoginItemService {
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("LoginItemService error: \(error)")
        }
    }
}
