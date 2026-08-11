import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKeys.showPreviewPane) private var showPreviewPane = true
    @AppStorage(SettingsKeys.showCommandBar) private var showCommandBar = true
    @AppStorage(SettingsKeys.commandBarStyle) private var commandBarStyle: CommandBarStyle = .iconAndText

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
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 380, height: 260)
    }
}

#Preview {
    SettingsView()
}
