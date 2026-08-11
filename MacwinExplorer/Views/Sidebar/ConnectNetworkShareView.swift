import SwiftUI

/// The GUI equivalent of Windows' `net use` — mounts an SMB/AFP/NFS share
/// via NetFS and, if checked, saves it for automatic reconnection at login.
struct ConnectNetworkShareView: View {
    let networkSharesStore: NetworkSharesStore
    var onMounted: (URL) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var address = "smb://"
    @State private var username = ""
    @State private var password = ""
    @State private var autoConnect = false
    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Подключить сетевую папку")
                .font(.title2.bold())
            Text("Например: smb://server/share или afp://server/share")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                TextField("Адрес", text: $address)
                TextField("Имя пользователя (необязательно)", text: $username)
                SecureField("Пароль (необязательно)", text: $password)
                Toggle("Подключать при запуске компьютера", isOn: $autoConnect)
            }
            .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            HStack {
                Spacer()
                Button("Отмена") { dismiss() }
                Button(isConnecting ? "Подключение…" : "Подключить") { connect() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty || isConnecting)
            }
        }
        .padding(24)
        .frame(width: 400)
    }

    private func connect() {
        errorMessage = nil
        isConnecting = true
        let addressToConnect = address.trimmingCharacters(in: .whitespaces)
        let userToConnect = username.isEmpty ? nil : username
        let passwordToConnect = password.isEmpty ? nil : password

        DispatchQueue.global(qos: .userInitiated).async {
            let result = NetworkShareService.mount(address: addressToConnect, username: userToConnect, password: passwordToConnect)
            DispatchQueue.main.async {
                isConnecting = false
                switch result {
                case .success(let paths):
                    var connection = NetworkShareConnection(address: addressToConnect, username: userToConnect, autoConnectAtLogin: autoConnect)
                    connection.lastMountPath = paths.first
                    networkSharesStore.add(connection, password: passwordToConnect)
                    if let firstPath = paths.first {
                        onMounted(URL(fileURLWithPath: firstPath))
                    }
                    dismiss()
                case .failure(let status):
                    errorMessage = "Не удалось подключиться (код \(status)). Проверьте адрес и данные для входа."
                }
            }
        }
    }
}
