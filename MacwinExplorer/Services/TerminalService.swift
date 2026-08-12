import Foundation
import AppKit

/// Drives Terminal.app.
///
/// "New window" shells out to `open -a Terminal <path>` instead of
/// AppleScript's `do script`: `do script` silently reuses the frontmost
/// window whenever its selected tab has no running process (i.e. it's just
/// sitting at an idle prompt) — the common case — which reads as "nothing
/// happened, focus just moved". `open` sends Terminal a plain "open
/// document" Apple Event, which has no such fallback and always creates a
/// genuinely new window; it also needs no extra permissions.
///
/// "New tab" has no non-GUI equivalent — Terminal's AppleScript dictionary
/// has no "make new tab" command — so it's simulated via ⌘T through
/// Accessibility, which requires the user to grant MacwinExplorer
/// Accessibility access once (System Settings ▸ Privacy & Security ▸
/// Accessibility). Without it the keystroke silently fails and only
/// `activate` runs, which looks identical to the `do script` reuse bug this
/// service otherwise avoids — so this is gated on that permission and
/// prompts for it instead of failing silently.
enum TerminalService {
    static func openNewWindow(at url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", url.path]
        do {
            try process.run()
        } catch {
            NSLog("TerminalService: failed to launch Terminal: \(error)")
        }
    }

    static func openNewTab(at url: URL) {
        guard PermissionsService.hasAccessibilityAccess() else {
            PermissionsService.promptForAccessibilityAccess()
            return
        }
        let literal = appleScriptLiteral(url.path)
        run(script: """
        tell application "Terminal"
            activate
            tell application "System Events" to keystroke "t" using command down
            delay 0.2
            do script "cd " & quoted form of \(literal) in front window
        end tell
        """)
    }

    /// Produces a safely-escaped AppleScript string literal (not shell
    /// quoting — that's handled inside the script via `quoted form of`).
    private static func appleScriptLiteral(_ string: String) -> String {
        let escaped = string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private static func run(script: String) {
        guard let appleScript = NSAppleScript(source: script) else { return }
        var error: NSDictionary?
        appleScript.executeAndReturnError(&error)
        if let error {
            NSLog("TerminalService AppleScript error: \(error)")
        }
    }
}
