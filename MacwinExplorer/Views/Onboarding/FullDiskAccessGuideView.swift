import SwiftUI

/// Shown automatically when the app doesn't have Full Disk Access, and
/// reachable again later from Settings. Walks through the one thing macOS
/// deliberately won't let an app do for itself: adding it to the Full Disk
/// Access list (the toggle still has to be flipped by a human).
struct FullDiskAccessGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKeys.dontShowFDAGuide) private var dontShowAgain = false

    @State private var justChecked = false
    @State private var accessGranted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "externaldrive.fill.badge.exclamationmark")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Нужен доступ к диску")
                        .font(.title2.bold())
                    Text("Без него macOS будет спрашивать разрешение отдельно на каждую защищённую папку — Рабочий стол, Загрузки, Документы.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                stepRow(1, "Нажмите «Открыть настройки» ниже")
                stepRow(2, "Нажмите + и выберите MacwinExplorer в Applications — либо просто перетащите иконку приложения прямо в список")
                stepRow(3, "Включите тумблер напротив MacwinExplorer")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))

            if justChecked && !accessGranted {
                Label("Пока не вижу доступа — проверьте, что тумблер включён", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.callout)
            }

            HStack {
                Toggle("Больше не показывать", isOn: $dontShowAgain)
                    .toggleStyle(.checkbox)
                Spacer()
                Button("Открыть настройки") {
                    PermissionsService.openFullDiskAccessSettings()
                }
                Button("Проверить") {
                    accessGranted = PermissionsService.hasFullDiskAccess()
                    justChecked = true
                    if accessGranted { dismiss() }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    @ViewBuilder
    private func stepRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.callout.bold())
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))
                .foregroundStyle(.white)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    FullDiskAccessGuideView()
}
