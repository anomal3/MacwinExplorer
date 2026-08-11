import Foundation
import AppKit
import Observation

/// A node in the sidebar tree. Reference type because NSOutlineView identifies
/// items by object identity, and folder children are loaded lazily on expand.
final class SidebarNode {
    enum Kind {
        case section, favorite, volume, folder, networkShare, networkAction
    }

    let kind: Kind
    let title: String
    let url: URL?
    /// Set only for `.favorite` nodes, so the sidebar context menu can remove
    /// the exact underlying FavoriteItem (URLs alone aren't a stable key —
    /// two favorites could theoretically point at the same folder briefly
    /// during a rename).
    let favoriteID: UUID?
    /// Set only for `.networkShare` nodes, mirroring `favoriteID`.
    let networkShareID: UUID?
    private(set) var children: [SidebarNode]
    private(set) var childrenLoaded: Bool

    init(
        kind: Kind, title: String, url: URL?,
        favoriteID: UUID? = nil, networkShareID: UUID? = nil,
        children: [SidebarNode] = [], childrenLoaded: Bool = true
    ) {
        self.kind = kind
        self.title = title
        self.url = url
        self.favoriteID = favoriteID
        self.networkShareID = networkShareID
        self.children = children
        self.childrenLoaded = childrenLoaded
    }

    var icon: NSImage? {
        switch kind {
        case .section, .networkAction:
            return nil
        case .favorite, .volume, .folder, .networkShare:
            guard let url else { return nil }
            return NSWorkspace.shared.icon(forFile: url.path)
        }
    }

    var isExpandable: Bool {
        switch kind {
        case .section: return !children.isEmpty
        case .favorite, .volume, .folder: return true
        case .networkShare: return url != nil
        case .networkAction: return false
        }
    }

    func loadChildrenIfNeeded() {
        guard !childrenLoaded, let url else { return }
        children = FileSystemService.subdirectories(of: url)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map { SidebarNode(kind: .folder, title: $0.name, url: $0.url, childrenLoaded: false) }
        childrenLoaded = true
    }
}

@Observable
final class SidebarViewModel {
    private(set) var rootNodes: [SidebarNode] = []
    var favoritesStore: FavoritesStore
    var networkSharesStore: NetworkSharesStore

    init(favoritesStore: FavoritesStore, networkSharesStore: NetworkSharesStore) {
        self.favoritesStore = favoritesStore
        self.networkSharesStore = networkSharesStore
    }

    func reload() {
        let favorites = SidebarNode(
            kind: .section, title: "Избранное", url: nil,
            children: favoritesStore.items.map {
                SidebarNode(kind: .favorite, title: $0.displayName, url: $0.url, favoriteID: $0.id, childrenLoaded: false)
            },
            childrenLoaded: true
        )
        let volumes = SidebarNode(
            kind: .section, title: "Этот Mac", url: nil,
            children: FileSystemService.mountedVolumes().map {
                SidebarNode(kind: .volume, title: $0.name, url: $0.url, childrenLoaded: false)
            },
            childrenLoaded: true
        )
        var networkChildren = networkSharesStore.connections.map { connection -> SidebarNode in
            let mountURL = connection.lastMountPath.map(URL.init(fileURLWithPath:))
            return SidebarNode(
                kind: .networkShare, title: connection.displayName, url: mountURL,
                networkShareID: connection.id, childrenLoaded: false
            )
        }
        networkChildren.append(SidebarNode(kind: .networkAction, title: "Подключить сетевую папку…", url: nil))
        let network = SidebarNode(kind: .section, title: "Сеть", url: nil, children: networkChildren, childrenLoaded: true)

        rootNodes = [favorites, volumes, network]
    }
}
