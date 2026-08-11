import Foundation
import AppKit
import Observation

/// A node in the sidebar tree. Reference type because NSOutlineView identifies
/// items by object identity, and folder children are loaded lazily on expand.
final class SidebarNode {
    enum Kind {
        case section, favorite, volume, folder
    }

    let kind: Kind
    let title: String
    let url: URL?
    private(set) var children: [SidebarNode]
    private(set) var childrenLoaded: Bool

    init(kind: Kind, title: String, url: URL?, children: [SidebarNode] = [], childrenLoaded: Bool = true) {
        self.kind = kind
        self.title = title
        self.url = url
        self.children = children
        self.childrenLoaded = childrenLoaded
    }

    var icon: NSImage? {
        guard kind != .section, let url else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    var isExpandable: Bool {
        switch kind {
        case .section: return !children.isEmpty
        case .favorite, .volume, .folder: return true
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

    func reload() {
        let favorites = SidebarNode(
            kind: .section, title: "Избранное", url: nil,
            children: FileSystemService.favoriteLocations().map {
                SidebarNode(kind: .favorite, title: $0.name, url: $0.url, childrenLoaded: false)
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
        rootNodes = [favorites, volumes]
    }
}
