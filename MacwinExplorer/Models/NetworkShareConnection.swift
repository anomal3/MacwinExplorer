import Foundation

struct NetworkShareConnection: Identifiable, Hashable, Codable {
    let id: UUID
    var address: String
    var username: String?
    var autoConnectAtLogin: Bool
    var displayName: String
    var lastMountPath: String?

    init(
        id: UUID = UUID(),
        address: String,
        username: String? = nil,
        autoConnectAtLogin: Bool = false,
        displayName: String? = nil,
        lastMountPath: String? = nil
    ) {
        self.id = id
        self.address = address
        self.username = username
        self.autoConnectAtLogin = autoConnectAtLogin
        self.displayName = displayName ?? Self.deriveName(from: address)
        self.lastMountPath = lastMountPath
    }

    static func deriveName(from address: String) -> String {
        guard let url = URL(string: address), let host = url.host else { return address }
        return url.path.isEmpty ? host : "\(host)\(url.path)"
    }
}
