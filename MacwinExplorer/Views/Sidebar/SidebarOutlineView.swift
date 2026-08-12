import SwiftUI
import AppKit

/// NSOutlineView subclass that adds a right-click context menu for managing
/// favorites (add a folder / volume, remove a favorite) — mirrors the
/// ExplorerTableView pattern used for the main file list.
final class FavoritesCapableOutlineView: NSOutlineView {
    var contextMenuProvider: ((SidebarNode?) -> NSMenu?)?

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let clickedRow = row(at: point)
        guard clickedRow >= 0 else { return contextMenuProvider?(nil) }
        if !selectedRowIndexes.contains(clickedRow) {
            selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
        }
        return contextMenuProvider?(item(atRow: clickedRow) as? SidebarNode)
    }
}

struct SidebarOutlineView: NSViewRepresentable {
    let viewModel: SidebarViewModel
    var onSelect: (URL) -> Void
    var onConnectNetworkShare: () -> Void
    var onDropFiles: (_ urls: [URL], _ destination: URL, _ move: Bool) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let outlineView = FavoritesCapableOutlineView()
        outlineView.headerView = nil
        outlineView.autoresizesOutlineColumn = true
        outlineView.style = .sourceList
        outlineView.floatsGroupRows = false
        outlineView.dataSource = context.coordinator
        outlineView.delegate = context.coordinator
        outlineView.registerForDraggedTypes([.fileURL])
        outlineView.contextMenuProvider = { node in context.coordinator.buildContextMenu(for: node) }

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SidebarColumn"))
        column.title = "Name"
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        let scrollView = NSScrollView()
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.viewModel = viewModel
        context.coordinator.onSelect = onSelect
        context.coordinator.onConnectNetworkShare = onConnectNetworkShare
        context.coordinator.onDropFiles = onDropFiles
        guard let outlineView = nsView.documentView as? NSOutlineView else { return }
        context.coordinator.reloadIfNeeded(outlineView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, onSelect: onSelect, onConnectNetworkShare: onConnectNetworkShare, onDropFiles: onDropFiles)
    }

    final class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
        var viewModel: SidebarViewModel
        var onSelect: (URL) -> Void
        var onConnectNetworkShare: () -> Void
        var onDropFiles: (_ urls: [URL], _ destination: URL, _ move: Bool) -> Void
        /// `reload()` rebuilds `rootNodes` with brand-new `SidebarNode`
        /// objects every time it runs, even when nothing actually changed,
        /// and SwiftUI calls `updateNSView` on nearly every re-render of the
        /// window — so reloading unconditionally would reset the outline
        /// view's selection/scroll position constantly. Reload only when the
        /// visible structure actually differs.
        private var displayedSnapshot = ""

        init(
            viewModel: SidebarViewModel,
            onSelect: @escaping (URL) -> Void,
            onConnectNetworkShare: @escaping () -> Void,
            onDropFiles: @escaping (_ urls: [URL], _ destination: URL, _ move: Bool) -> Void
        ) {
            self.viewModel = viewModel
            self.onSelect = onSelect
            self.onConnectNetworkShare = onConnectNetworkShare
            self.onDropFiles = onDropFiles
        }

        func reloadIfNeeded(_ outlineView: NSOutlineView) {
            let current = Self.snapshot(viewModel.rootNodes)
            guard current != displayedSnapshot else { return }
            displayedSnapshot = current
            outlineView.reloadData()
            for node in viewModel.rootNodes {
                outlineView.expandItem(node)
            }
        }

        private static func snapshot(_ nodes: [SidebarNode]) -> String {
            nodes.map { section in
                let children = section.children.map {
                    "\($0.kind)|\($0.title)|\($0.url?.path ?? "")|\($0.favoriteID?.uuidString ?? "")|\($0.networkShareID?.uuidString ?? "")"
                }.joined(separator: ",")
                return "\(section.title):[\(children)]"
            }.joined(separator: ";")
        }

        private func node(_ item: Any?) -> SidebarNode? { item as? SidebarNode }

        func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            guard let item else { return viewModel.rootNodes.count }
            guard let n = node(item) else { return 0 }
            n.loadChildrenIfNeeded()
            return n.children.count
        }

        func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            node(item)?.isExpandable ?? false
        }

        func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            guard let item else { return viewModel.rootNodes[index] }
            let n = node(item)!
            n.loadChildrenIfNeeded()
            return n.children[index]
        }

        func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
            guard let n = node(item) else { return nil }
            let identifier = NSUserInterfaceItemIdentifier("SidebarCell")
            let cell: NSTableCellView
            if let reused = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
                cell = reused
            } else {
                cell = NSTableCellView()
                cell.identifier = identifier
                let imageView = NSImageView()
                imageView.translatesAutoresizingMaskIntoConstraints = false
                let textField = NSTextField(labelWithString: "")
                textField.translatesAutoresizingMaskIntoConstraints = false
                textField.lineBreakMode = .byTruncatingTail
                textField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))
                cell.imageView = imageView
                cell.textField = textField
                cell.addSubview(imageView)
                cell.addSubview(textField)
                NSLayoutConstraint.activate([
                    imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
                    imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    imageView.widthAnchor.constraint(equalToConstant: 16),
                    imageView.heightAnchor.constraint(equalToConstant: 16),
                    textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                    textField.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor),
                    textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                ])
            }
            cell.textField?.stringValue = n.title
            cell.imageView?.image = n.icon
            cell.imageView?.isHidden = n.kind == .section
            return cell
        }

        func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
            node(item)?.kind == .section
        }

        func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
            node(item)?.kind != .section
        }

        func outlineViewSelectionDidChange(_ notification: Notification) {
            guard let outlineView = notification.object as? NSOutlineView else { return }
            let row = outlineView.selectedRow
            guard row >= 0, let n = outlineView.item(atRow: row) as? SidebarNode else { return }

            if n.kind == .networkAction {
                onConnectNetworkShare()
                return
            }
            if n.kind == .networkShare {
                if let url = n.url, FileManager.default.fileExists(atPath: url.path) {
                    onSelect(url)
                } else if let id = n.networkShareID,
                          let connection = viewModel.networkSharesStore.connections.first(where: { $0.id == id }) {
                    reconnect(connection)
                }
                return
            }
            guard let url = n.url else { return }
            onSelect(url)
        }

        private func reconnect(_ connection: NetworkShareConnection) {
            let password = viewModel.networkSharesStore.password(for: connection)
            let sharesStore = viewModel.networkSharesStore
            let selectHandler = onSelect
            DispatchQueue.global(qos: .userInitiated).async {
                let result = NetworkShareService.mount(address: connection.address, username: connection.username, password: password)
                guard case .success(let paths) = result, let path = paths.first else { return }
                DispatchQueue.main.async {
                    sharesStore.updateLastMountPath(path, for: connection)
                    selectHandler(URL(fileURLWithPath: path))
                }
            }
        }

        // MARK: - Drag and drop (files dropped from the file list or from Finder)

        func outlineView(
            _ outlineView: NSOutlineView,
            validateDrop info: NSDraggingInfo,
            proposedItem item: Any?,
            proposedChildIndex index: Int
        ) -> NSDragOperation {
            guard let target = node(item), dropTarget(for: target) != nil else { return [] }
            guard info.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: nil) else { return [] }
            outlineView.setDropItem(item, dropChildIndex: NSOutlineViewDropOnItemIndex)
            return DragDropDefaultAction.resolved() == .copy ? .copy : .move
        }

        func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
            guard let target = node(item), let destination = dropTarget(for: target) else { return false }
            guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty else {
                return false
            }
            onDropFiles(urls, destination, DragDropDefaultAction.resolved() == .move)
            return true
        }

        /// Only real folders (favorite / volume / folder / mounted network
        /// share) can receive a drop — not section headers or the
        /// "connect a share" action row.
        private func dropTarget(for node: SidebarNode) -> URL? {
            switch node.kind {
            case .favorite, .volume, .folder:
                return node.url
            case .networkShare:
                guard let url = node.url, FileManager.default.fileExists(atPath: url.path) else { return nil }
                return url
            case .section, .networkAction:
                return nil
            }
        }

        // MARK: - Context menu

        func buildContextMenu(for node: SidebarNode?) -> NSMenu? {
            guard let node else { return nil }
            let menu = NSMenu()
            switch node.kind {
            case .favorite:
                let removeItem = menu.addItem(withTitle: "Удалить из избранного", action: #selector(removeFavorite(_:)), keyEquivalent: "")
                removeItem.target = self
                removeItem.representedObject = node
            case .volume, .folder:
                guard let url = node.url else { return nil }
                let alreadyFavorite = viewModel.favoritesStore.contains(url)
                let addItem = menu.addItem(
                    withTitle: alreadyFavorite ? "Уже в избранном" : "Добавить в избранное",
                    action: alreadyFavorite ? nil : #selector(addFavorite(_:)),
                    keyEquivalent: ""
                )
                addItem.target = self
                addItem.isEnabled = !alreadyFavorite
                addItem.representedObject = node
            case .networkShare:
                let removeItem = menu.addItem(withTitle: "Удалить сетевую папку", action: #selector(removeNetworkShare(_:)), keyEquivalent: "")
                removeItem.target = self
                removeItem.representedObject = node
            case .section, .networkAction:
                return nil
            }
            return menu
        }

        @objc private func addFavorite(_ sender: NSMenuItem) {
            guard let node = sender.representedObject as? SidebarNode, let url = node.url else { return }
            viewModel.favoritesStore.add(url)
            viewModel.reload()
        }

        @objc private func removeFavorite(_ sender: NSMenuItem) {
            guard let node = sender.representedObject as? SidebarNode, let id = node.favoriteID,
                  let item = viewModel.favoritesStore.items.first(where: { $0.id == id }) else { return }
            viewModel.favoritesStore.remove(item)
            viewModel.reload()
        }

        @objc private func removeNetworkShare(_ sender: NSMenuItem) {
            guard let node = sender.representedObject as? SidebarNode, let id = node.networkShareID,
                  let connection = viewModel.networkSharesStore.connections.first(where: { $0.id == id }) else { return }
            viewModel.networkSharesStore.remove(connection)
            viewModel.reload()
        }
    }
}
