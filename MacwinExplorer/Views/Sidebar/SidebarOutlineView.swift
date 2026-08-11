import SwiftUI
import AppKit

struct SidebarOutlineView: NSViewRepresentable {
    let viewModel: SidebarViewModel
    var onSelect: (URL) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.autoresizesOutlineColumn = true
        outlineView.style = .sourceList
        outlineView.floatsGroupRows = false
        outlineView.dataSource = context.coordinator
        outlineView.delegate = context.coordinator

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
        guard let outlineView = nsView.documentView as? NSOutlineView else { return }
        outlineView.reloadData()
        for node in viewModel.rootNodes {
            outlineView.expandItem(node)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, onSelect: onSelect)
    }

    final class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
        var viewModel: SidebarViewModel
        var onSelect: (URL) -> Void

        init(viewModel: SidebarViewModel, onSelect: @escaping (URL) -> Void) {
            self.viewModel = viewModel
            self.onSelect = onSelect
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
            guard row >= 0, let n = outlineView.item(atRow: row) as? SidebarNode, let url = n.url else { return }
            onSelect(url)
        }
    }
}
