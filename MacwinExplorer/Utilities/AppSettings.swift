import AppKit

enum SettingsKeys {
    static let showPreviewPane = "showPreviewPane"
    static let showCommandBar = "showCommandBar"
    static let commandBarStyle = "commandBarStyle"
    static let dontShowFDAGuide = "dontShowFDAGuide"
    static let fileViewMode = "fileViewMode"
    static let confirmBeforeQuit = "confirmBeforeQuit"
    static let showMenuBarIcon = "showMenuBarIcon"
    static let newWindowHotKeyCode = "newWindowHotKeyCode"
    static let newWindowHotKeyModifiers = "newWindowHotKeyModifiers"
    static let dragDropDefaultAction = "dragDropDefaultAction"
}

/// What a plain drag-and-drop (no modifier keys) does by default. Holding
/// ⌥ always forces copy and ⌘ always forces move, regardless of this
/// setting — matching the modifier convention users already expect.
enum DragDropDefaultAction: String, CaseIterable, Identifiable {
    case copy
    case move

    var id: String { rawValue }

    var label: String {
        switch self {
        case .copy: return "Копировать"
        case .move: return "Перемещать"
        }
    }

    static func resolved() -> DragDropDefaultAction {
        let modifiers = NSEvent.modifierFlags
        if modifiers.contains(.option) { return .copy }
        if modifiers.contains(.command) { return .move }
        let raw = UserDefaults.standard.string(forKey: SettingsKeys.dragDropDefaultAction)
        return raw.flatMap(DragDropDefaultAction.init) ?? .copy
    }
}

/// Windows-Explorer-style "Large icons" vs "Details" view switch.
enum FileViewMode: String, CaseIterable {
    case details
    case icons
}

/// Mirrors the three options macOS's own toolbar customization sheet offers.
enum CommandBarStyle: String, CaseIterable, Identifiable {
    case iconAndText
    case iconOnly
    case textOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .iconAndText: return "Иконки и текст"
        case .iconOnly: return "Только иконки"
        case .textOnly: return "Только текст"
        }
    }
}
