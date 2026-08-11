import SwiftUI
import AppKit

struct SettingsView: View {
    let networkSharesStore: NetworkSharesStore

    @AppStorage(SettingsKeys.showPreviewPane) private var showPreviewPane = true
    @AppStorage(SettingsKeys.showCommandBar) private var showCommandBar = true
    @AppStorage(SettingsKeys.commandBarStyle) private var commandBarStyle: CommandBarStyle = .iconAndText
    @AppStorage(SettingsKeys.confirmBeforeQuit) private var confirmBeforeQuit = true
    @AppStorage(SettingsKeys.showMenuBarIcon) private var showMenuBarIcon = false

    @State private var hasFullDiskAccess = PermissionsService.hasFullDiskAccess()
    @State private var showFDAGuide = false

    @State private var hotKeyDisplayText = SettingsView.currentHotKeyDisplayText()
    @State private var hotKeyConflictMessage: String?

    private var hasSavedHotKey: Bool {
        UserDefaults.standard.object(forKey: SettingsKeys.newWindowHotKeyCode) != nil
    }

    var body: some View {
        Form {
            Section("Панель инструментов") {
                Toggle("Показывать панель инструментов", isOn: $showCommandBar)
                Picker("Вид кнопок", selection: $commandBarStyle) {
                    ForEach(CommandBarStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                .disabled(!showCommandBar)
            }

            Section("Предпросмотр") {
                Toggle("Показывать панель предпросмотра справа", isOn: $showPreviewPane)
            }

            Section("Строка меню") {
                Toggle("Значок в строке меню (избранное + выход)", isOn: $showMenuBarIcon)
            }

            Section("Горячая клавиша: новое окно") {
                HStack {
                    Text("Комбинация")
                    Spacer()
                    HotKeyRecorderView(displayText: hotKeyDisplayText) { keyCode, modifiers in
                        attemptRegister(keyCode: keyCode, modifiers: modifiers)
                    }
                    .frame(width: 160, height: 24)
                    if hasSavedHotKey {
                        Button("Сбросить") { clearHotKey() }
                    }
                }
                if let hotKeyConflictMessage {
                    Text(hotKeyConflictMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            if !networkSharesStore.connections.isEmpty {
                Section("Сетевые папки") {
                    ForEach(networkSharesStore.connections) { connection in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(connection.displayName)
                                Text(connection.address)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("При запуске", isOn: Binding(
                                get: { connection.autoConnectAtLogin },
                                set: { newValue in
                                    let existingPassword = networkSharesStore.password(for: connection)
                                    var updated = connection
                                    updated.autoConnectAtLogin = newValue
                                    networkSharesStore.remove(connection)
                                    networkSharesStore.add(updated, password: existingPassword)
                                }
                            ))
                            .toggleStyle(.checkbox)
                            Button(role: .destructive) {
                                networkSharesStore.remove(connection)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Section("Выход из приложения") {
                Toggle("Подтверждать перед выходом (⌘Q)", isOn: $confirmBeforeQuit)
            }

            Section("Доступ к диску") {
                HStack {
                    Circle()
                        .fill(hasFullDiskAccess ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(hasFullDiskAccess ? "Full Disk Access разрешён" : "Full Disk Access не разрешён")
                    Spacer()
                    Button("Гайд") { showFDAGuide = true }
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 420, height: 560)
        .onAppear { hasFullDiskAccess = PermissionsService.hasFullDiskAccess() }
        .sheet(isPresented: $showFDAGuide, onDismiss: {
            hasFullDiskAccess = PermissionsService.hasFullDiskAccess()
        }) {
            FullDiskAccessGuideView()
        }
    }

    private static func currentHotKeyDisplayText() -> String {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: SettingsKeys.newWindowHotKeyCode) != nil else { return "Не задано" }
        let keyCode = UInt16(defaults.integer(forKey: SettingsKeys.newWindowHotKeyCode))
        let modifiers = NSEvent.ModifierFlags(rawValue: UInt(defaults.integer(forKey: SettingsKeys.newWindowHotKeyModifiers)))
        return KeyCodeNames.displayString(keyCode: keyCode, modifiers: modifiers)
    }

    private func attemptRegister(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        if let conflict = SystemShortcutBlocklist.conflictDescription(keyCode: keyCode, modifiers: modifiers) {
            hotKeyConflictMessage = "Эта комбинация уже используется системой (\(conflict)) — выберите другую."
            return
        }
        let success = GlobalHotKeyService.shared.register(keyCode: UInt32(keyCode), carbonModifiers: modifiers.carbonFlags)
        if success {
            UserDefaults.standard.set(Int(keyCode), forKey: SettingsKeys.newWindowHotKeyCode)
            UserDefaults.standard.set(Int(modifiers.rawValue), forKey: SettingsKeys.newWindowHotKeyModifiers)
            hotKeyDisplayText = KeyCodeNames.displayString(keyCode: keyCode, modifiers: modifiers)
            hotKeyConflictMessage = nil
        } else {
            hotKeyConflictMessage = "Эта комбинация уже используется другим приложением — выберите другую."
        }
    }

    private func clearHotKey() {
        GlobalHotKeyService.shared.unregister()
        UserDefaults.standard.removeObject(forKey: SettingsKeys.newWindowHotKeyCode)
        UserDefaults.standard.removeObject(forKey: SettingsKeys.newWindowHotKeyModifiers)
        hotKeyDisplayText = "Не задано"
        hotKeyConflictMessage = nil
    }
}

#Preview {
    SettingsView(networkSharesStore: NetworkSharesStore())
}
