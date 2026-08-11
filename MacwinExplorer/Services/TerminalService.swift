import Foundation
import AppKit

/// Drives Terminal.app via Apple Events. The first call triggers the
/// standard macOS "MacwinExplorer wants to control Terminal" consent prompt —
/// that's expected and only asked once.
enum TerminalService {
    static func openNewWindow(at url: URL) {
        let literal = appleScriptLiteral(url.path)
        run(script: """
        tell application "Terminal"
            activate
            do script "cd " & quoted form of \(literal)
        end tell
        """)
    }

    static func openNewTab(at url: URL) {
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
