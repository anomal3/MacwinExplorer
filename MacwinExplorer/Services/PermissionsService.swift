import AppKit

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
}
