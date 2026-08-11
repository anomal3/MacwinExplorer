import Foundation
import Observation

@Observable
final class NetworkSharesStore {
    private(set) var connections: [NetworkShareConnection] = []
    private let storageKey = "networkShareConnections"
    private static var hasAttemptedAutoReconnectThisLaunch = false

    init() {
        load()
    }

    func add(_ connection: NetworkShareConnection, password: String?) {
        connections.append(connection)
        if let password {
            KeychainService.savePassword(password, account: connection.id.uuidString)
        }
        save()
        updateLoginItemRegistration()
    }

    func remove(_ connection: NetworkShareConnection) {
        connections.removeAll { $0.id == connection.id }
        KeychainService.deletePassword(account: connection.id.uuidString)
        save()
        updateLoginItemRegistration()
    }

    func updateLastMountPath(_ path: String, for connection: NetworkShareConnection) {
        guard let index = connections.firstIndex(where: { $0.id == connection.id }) else { return }
        connections[index].lastMountPath = path
        save()
    }

    func password(for connection: NetworkShareConnection) -> String? {
        KeychainService.readPassword(account: connection.id.uuidString)
    }

    /// Called once on launch: remounts every share flagged "auto-connect at login".
    /// Guarded so calling it again from a second window's onAppear is a no-op.
    func reconnectAutoMountShares() {
        guard !Self.hasAttemptedAutoReconnectThisLaunch else { return }
        Self.hasAttemptedAutoReconnectThisLaunch = true
        for connection in connections where connection.autoConnectAtLogin {
            let storedPassword = password(for: connection)
            let result = NetworkShareService.mount(address: connection.address, username: connection.username, password: storedPassword)
            if case .success(let paths) = result, let path = paths.first {
                updateLastMountPath(path, for: connection)
            }
        }
    }

    private func updateLoginItemRegistration() {
        LoginItemService.setEnabled(connections.contains { $0.autoConnectAtLogin })
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([NetworkShareConnection].self, from: data) else { return }
        connections = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(connections) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
