import Carbon
import AppKit

/// Registers a single system-wide hotkey (used to open a new window even
/// when the app isn't focused) via the classic Carbon Hot Key Manager —
/// still the simplest way to do this without requesting Accessibility /
/// Input Monitoring permission.
final class GlobalHotKeyService {
    static let shared = GlobalHotKeyService()

    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerInstalled = false
    private let hotKeyID = EventHotKeyID(signature: OSType(0x4D57_4558), id: 1) // 'MWEX'

    private init() {}

    /// Attempts to register `keyCode`/`carbonModifiers` as the global hotkey.
    /// Returns false if another app already owns that combination — in that
    /// case nothing changes (the previous shortcut, if any, stays active).
    @discardableResult
    func register(keyCode: UInt32, carbonModifiers: UInt32) -> Bool {
        installEventHandlerIfNeeded()

        var newRef: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, carbonModifiers, hotKeyID, GetEventDispatcherTarget(), 0, &newRef)
        guard status == noErr, let newRef else { return false }

        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = newRef
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    /// Modifiers are persisted as NSEvent.ModifierFlags.rawValue (not Carbon
    /// bits) so Settings can redisplay "⌘⇧O" without a reverse mapping;
    /// they're converted to Carbon bits only right before registering.
    func applySavedShortcut() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: SettingsKeys.newWindowHotKeyCode) != nil else { return }
        let keyCode = UInt32(defaults.integer(forKey: SettingsKeys.newWindowHotKeyCode))
        let modifierRaw = UInt(defaults.integer(forKey: SettingsKeys.newWindowHotKeyModifiers))
        let modifiers = NSEvent.ModifierFlags(rawValue: modifierRaw)
        register(keyCode: keyCode, carbonModifiers: modifiers.carbonFlags)
    }

    private func installEventHandlerIfNeeded() {
        guard !eventHandlerInstalled else { return }
        eventHandlerInstalled = true

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, eventRef, _ -> OSStatus in
            var pressedID = EventHotKeyID()
            GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &pressedID
            )
            if pressedID.id == 1 {
                DispatchQueue.main.async {
                    GlobalHotKeyService.shared.onTrigger?()
                }
            }
            return noErr
        }, 1, &eventType, nil, nil)
    }
}

extension NSEvent.ModifierFlags {
    /// Converts the recorder's NSEvent modifiers into Carbon's bitmask.
    var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) { flags |= UInt32(cmdKey) }
        if contains(.shift) { flags |= UInt32(shiftKey) }
        if contains(.option) { flags |= UInt32(optionKey) }
        if contains(.control) { flags |= UInt32(controlKey) }
        return flags
    }
}

/// A best-effort list of very common system shortcuts. macOS exposes no API
/// to enumerate every reserved combination, so this catches the obvious
/// ones proactively; anything else relies on the registration itself
/// failing when it's already claimed by another app.
enum SystemShortcutBlocklist {
    private static let entries: [(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, name: String)] = [
        (49, [.command], "Spotlight (⌘Пробел)"),
        (48, [.command], "Переключение приложений (⌘Tab)"),
        (50, [.command], "Переключение окон приложения (⌘`)"),
        (12, [.command], "Выход из приложения (⌘Q)"),
        (13, [.command], "Закрыть окно (⌘W)"),
        (20, [.command, .shift], "Скриншот всего экрана (⌘⇧3)"),
        (21, [.command, .shift], "Скриншот области (⌘⇧4)"),
        (23, [.command, .shift], "Скриншот со Screenshot-панелью (⌘⇧5)"),
        (123, [.control], "Mission Control / Spaces (⌃←)"),
        (124, [.control], "Mission Control / Spaces (⌃→)"),
        (126, [.control], "Mission Control (⌃↑)"),
        (125, [.control], "App Exposé (⌃↓)")
    ]

    static func conflictDescription(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String? {
        let relevant = modifiers.intersection([.command, .shift, .option, .control])
        return entries.first { $0.keyCode == keyCode && $0.modifiers == relevant }?.name
    }
}
