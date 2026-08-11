import Foundation
import NetFS

/// Mounts SMB/AFP/NFS shares programmatically via NetFS — the same
/// mechanism Finder's "Connect to Server" uses — instead of shelling out,
/// so the whole flow stays inside our own GUI.
enum NetworkShareService {
    enum MountResult {
        case success(mountedPaths: [String])
        case failure(status: Int32)
    }

    static func mount(address: String, username: String?, password: String?) -> MountResult {
        guard let url = URL(string: address) else { return .failure(status: -1) }

        let openOptions: NSMutableDictionary = [kNAUIOptionKey: kNAUIOptionNoUI]
        var mountPoints: Unmanaged<CFArray>?

        let status = NetFSMountURLSync(
            url as CFURL,
            nil,
            username as CFString?,
            password as CFString?,
            openOptions,
            nil,
            &mountPoints
        )

        guard status == 0 else { return .failure(status: status) }
        let paths = (mountPoints?.takeRetainedValue() as? [String]) ?? []
        return .success(mountedPaths: paths)
    }
}
