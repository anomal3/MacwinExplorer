import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKeys.showPreviewPane) private var showPreviewPane = true
    @AppStorage(SettingsKeys.showCommandBar) private var showCommandBar = true
    @AppStorage(SettingsKeys.commandBarStyle) private var commandBarStyle: CommandBarStyle = .iconAndText

    @State private var hasFullDiskAccess = PermissionsService.hasFullDiskAccess()
    @State private var showFDAGuide = false

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
        .frame(width: 380, height: 340)
        .onAppear { hasFullDiskAccess = PermissionsService.hasFullDiskAccess() }
        .sheet(isPresented: $showFDAGuide, onDismiss: {
            hasFullDiskAccess = PermissionsService.hasFullDiskAccess()
        }) {
            FullDiskAccessGuideView()
        }
    }
}

#Preview {
    SettingsView()
}
