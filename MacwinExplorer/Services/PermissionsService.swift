import AppKit
import ApplicationServices

enum PermissionsService {
    /// There is no public API that reports Full Disk Access status directly.
    /// The standard workaround (used by many indie Mac utilities) is to try
    /// reading a file that only a Full-Disk-Access-granted process can read —
    /// the system's own TCC database, which exists on every Mac.
    static func hasFullDiskAccess() -> Bool {
        let tccPath = "/Library/Application Support/com.apple.TCC/TCC.db"
        return FileManager.default.contents(atPath: tccPath) != nil
    }

    static func openFullDiskAccessSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else { return }
        NSWorkspace.shared.open(url)
    }

    static func hasAccessibilityAccess() -> Bool {
        AXIsProcessTrusted()
    }

    /// Triggers the standard macOS "MacwinExplorer would like to control
    /// this computer using accessibility features" prompt, which also adds
    /// the app to System Settings ▸ Privacy & Security ▸ Accessibility so
    /// the user can enable it there.
    static func promptForAccessibilityAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
}
