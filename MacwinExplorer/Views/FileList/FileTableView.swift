import SwiftUI
import AppKit

private extension NSUserInterfaceItemIdentifier {
    static let name = NSUserInterfaceItemIdentifier("name")
    static let dateModified = NSUserInterfaceItemIdentifier("dateModified")
    static let kind = NSUserInterfaceItemIdentifier("kind")
    static let size = NSUserInterfaceItemIdentifier("size")
}

/// NSTableView subclass that adds a dynamic right-click context menu and
/// standard-shortcut handling (Cmd+C/X/V, Delete, Return-to-rename) — the
/// same actions the context menu and command bar expose, so every path
/// (hotkey, menu, toolbar button) drives the same underlying operations.
final class ExplorerTableView: NSTableView {
    var contextMenuProvider: ((Int?) -> NSMenu?)?
    var onCopy: (() -> Void)?
    var onCut: (() -> Void)?
    var onPaste: (() -> Void)?
    var onDeleteKey: (() -> Void)?
    var onRenameRequest: (() -> Void)?

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let clickedRow = row(at: point)
        if clickedRow >= 0 && !selectedRowIndexes.contains(clickedRow) {
            selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
        }
        return contextMenuProvider?(clickedRow >= 0 ? clickedRow : nil)
    }

    // Not superclass overrides: NSResponder doesn't declare these, but AppKit
    // dispatches the standard Cmd+C/X/V key equivalents to whichever
    // responder implements them, first responder down the chain.
    @objc func copy(_ sender: Any?) { onCopy?() }
    @objc func cut(_ sender: Any?) { onCut?() }
    @objc func paste(_ sender: Any?) { onPaste?() }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 51, 117: // Delete (Backspace) / Forward Delete
            onDeleteKey?()
        case 36, 76: // Return / numpad Enter
            onRenameRequest?()
        default:
            super.keyDown(with: event)
        }
    }
}

struct FileTableView: NSViewRepresentable {
    let viewModel: FileListViewModel
    let favoritesStore: FavoritesStore
    var currentDirectory: URL
    @Binding var renameRequested: Bool
    var onNavigate: (URL) -> Void
    var onOpenFile: (URL) -> Void
    var onShowProperties: ([FileSystemItem]) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let tableView = ExplorerTableView()
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = true
        tableView.doubleAction = #selector(Coordinator.doubleClicked(_:))
        tableView.target = context.coordinator

        let nameColumn = NSTableColumn(identifier: .name)
        nameColumn.title = "Имя"
        nameColumn.width = 260
        nameColumn.sortDescriptorPrototype = NSSortDescriptor(key: SortColumn.name.rawValue, ascending: true)

        let dateColumn = NSTableColumn(identifier: .dateModified)
        dateColumn.title = "Дата изменения"
        dateColumn.width = 160
        dateColumn.sortDescriptorPrototype = NSSortDescriptor(key: SortColumn.dateModified.rawValue, ascending: true)

        let kindColumn = NSTableColumn(identifier: .kind)
        kindColumn.title = "Тип"
        kindColumn.width = 130
        kindColumn.sortDescriptorPrototype = NSSortDescriptor(key: SortColumn.kind.rawValue, ascending: true)

        let sizeColumn = NSTableColumn(identifier: .size)
        sizeColumn.title = "Размер"
        sizeColumn.width = 90
        sizeColumn.sortDescriptorPrototype = NSSortDescriptor(key: SortColumn.size.rawValue, ascending: true)

        for column in [nameColumn, dateColumn, kindColumn, sizeColumn] {
            tableView.addTableColumn(column)
        }

        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.registerForDraggedTypes([.fileURL])
        tableView.setDraggingSourceOperationMask([.copy, .move], forLocal: true)
        tableView.setDraggingSourceOperationMask([.copy, .move], forLocal: false)
        tableView.contextMenuProvider = { row in context.coordinator.buildContextMenu(for: row) }
        tableView.onCopy = { context.coordinator.copySelected() }
        tableView.onCut = { context.coordinator.cutSelected() }
        tableView.onPaste = { context.coordinator.pasteIntoCurrent() }
        tableView.onDeleteKey = { context.coordinator.deleteSelected() }
        tableView.onRenameRequest = { context.coordinator.startRenameSelected() }
        context.coordinator.tableView = tableView

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.viewModel = viewModel
        context.coordinator.favoritesStore = favoritesStore
        context.coordinator.currentDirectory = currentDirectory
        context.coordinator.onNavigate = onNavigate
        context.coordinator.onOpenFile = onOpenFile
        context.coordinator.onShowProperties = onShowProperties
        guard let tableView = nsView.documentView as? ExplorerTableView else { return }
        tableView.reloadData()

        if renameRequested {
            context.coordinator.startRenameSelected()
            DispatchQueue.main.async { renameRequested = false }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            viewModel: viewModel,
            favoritesStore: favoritesStore,
            currentDirectory: currentDirectory,
            onNavigate: onNavigate,
            onOpenFile: onOpenFile,
            onShowProperties: onShowProperties
        )
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
        var viewModel: FileListViewModel
        var favoritesStore: FavoritesStore
        var currentDirectory: URL
        var onNavigate: (URL) -> Void
        var onOpenFile: (URL) -> Void
        var onShowProperties: ([FileSystemItem]) -> Void
        weak var tableView: NSTableView?

        init(
            viewModel: FileListViewModel,
            favoritesStore: FavoritesStore,
            currentDirectory: URL,
            onNavigate: @escaping (URL) -> Void,
            onOpenFile: @escaping (URL) -> Void,
            onShowProperties: @escaping ([FileSystemItem]) -> Void
        ) {
            self.viewModel = viewModel
            self.favoritesStore = favoritesStore
            self.currentDirectory = currentDirectory
            self.onNavigate = onNavigate
            self.onOpenFile = onOpenFile
            self.onShowProperties = onShowProperties
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            viewModel.sortedItems.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let identifier = tableColumn?.identifier else { return nil }
            let items = viewModel.sortedItems
            guard row < items.count else { return nil }
            let item = items[row]
            let cellID = NSUserInterfaceItemIdentifier("Cell-\(identifier.rawValue)")

            let cell: NSTableCellView
            if let reused = tableView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView {
                cell = reused
            } else {
                cell = NSTableCellView()
                cell.identifier = cellID
                let textField: NSTextField
                if identifier == .name {
                    textField = NSTextField()
                    textField.isBordered = false
                    textField.drawsBackground = false
                    textField.isEditable = true
                    textField.isSelectable = true
                    textField.delegate = self
                    textField.lineBreakMode = .byTruncatingTail
                } else {
                    textField = NSTextField(labelWithString: "")
                    textField.lineBreakMode = .byTruncatingTail
                }
                textField.translatesAutoresizingMaskIntoConstraints = false
                cell.textField = textField
                cell.addSubview(textField)
                if identifier == .name {
                    let imageView = NSImageView()
                    imageView.translatesAutoresizingMaskIntoConstraints = false
                    cell.imageView = imageView
                    cell.addSubview(imageView)
                    NSLayoutConstraint.activate([
                        imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                        imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                        imageView.widthAnchor.constraint(equalToConstant: 16),
                        imageView.heightAnchor.constraint(equalToConstant: 16),
                        textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                        textField.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -4),
                        textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                    ])
                } else {
                    NSLayoutConstraint.activate([
                        textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                        textField.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -4),
                        textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                    ])
                }
            }

            switch identifier {
            case .name:
                cell.textField?.stringValue = item.name
                cell.imageView?.image = item.icon
                cell.textField?.alignment = .left
            case .dateModified:
                cell.textField?.stringValue = item.modificationDate.map { DateFormatter.explorerStyle.string(from: $0) } ?? ""
                cell.textField?.alignment = .left
            case .kind:
                cell.textField?.stringValue = item.kindDescription
                cell.textField?.alignment = .left
            case .size:
                cell.textField?.stringValue = item.isDirectory ? "" : (item.size.map(FileSizeFormatter.string) ?? "")
                cell.textField?.alignment = .right
            default:
                break
            }
            return cell
        }

        func tableView(_ tableView: NSTableView, shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool {
            tableColumn?.identifier == .name && viewModel.selection.count == 1
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField, let tableView else { return }
            let row = tableView.row(for: textField)
            guard row >= 0, row < viewModel.sortedItems.count else { return }
            let item = viewModel.sortedItems[row]
            let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newName.isEmpty && newName != item.name {
                viewModel.performRename(item.url, to: newName, in: currentDirectory)
            } else {
                textField.stringValue = item.name
            }
        }

        func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
            guard let descriptor = tableView.sortDescriptors.first,
                  let key = descriptor.key, let column = SortColumn(rawValue: key) else { return }
            viewModel.sortColumn = column
            viewModel.sortAscending = descriptor.ascending
            tableView.reloadData()
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tableView = notification.object as? NSTableView else { return }
            let items = viewModel.sortedItems
            let selectedURLs = tableView.selectedRowIndexes.compactMap { $0 < items.count ? items[$0].url : nil }
            viewModel.selection = Set(selectedURLs)
        }

        // MARK: - Drag and drop

        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
            guard row < viewModel.sortedItems.count else { return nil }
            return viewModel.sortedItems[row].url as NSURL
        }

        func tableView(
            _ tableView: NSTableView,
            validateDrop info: NSDraggingInfo,
            proposedRow row: Int,
            proposedDropOperation dropOperation: NSTableView.DropOperation
        ) -> NSDragOperation {
            guard info.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: nil) else { return [] }
            let items = viewModel.sortedItems
            let droppingOnFolder = dropOperation == .on && row >= 0 && row < items.count && items[row].isDirectory
            if !droppingOnFolder {
                // Redirect anywhere else (between rows, empty area) to a
                // single whole-view highlight meaning "drop into this folder".
                tableView.setDropRow(-1, dropOperation: .on)
            }
            return DragDropDefaultAction.resolved() == .copy ? .copy : .move
        }

        func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
            guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty else {
                return false
            }
            let items = viewModel.sortedItems
            let destination: URL
            if dropOperation == .on, row >= 0, row < items.count, items[row].isDirectory {
                destination = items[row].url
            } else {
                destination = currentDirectory
            }
            let move = DragDropDefaultAction.resolved() == .move
            viewModel.performDrop(urls: urls, into: destination, move: move, currentDirectory: currentDirectory)
            return true
        }

        @objc func doubleClicked(_ sender: NSTableView) {
            let row = sender.clickedRow
            guard row >= 0, row < viewModel.sortedItems.count else { return }
            let item = viewModel.sortedItems[row]
            if item.isDirectory {
                onNavigate(item.url)
            } else {
                onOpenFile(item.url)
            }
        }

        // MARK: - Actions shared by keyboard shortcuts, context menu, and the command bar

        func copySelected() {
            viewModel.performCopy(Array(viewModel.selection))
        }

        func cutSelected() {
            viewModel.performCut(Array(viewModel.selection))
        }

        func pasteIntoCurrent() {
            viewModel.performPaste(in: currentDirectory)
        }

        func deleteSelected() {
            guard !viewModel.selection.isEmpty else { return }
            viewModel.performDelete(Array(viewModel.selection), in: currentDirectory)
        }

        func startRenameSelected() {
            guard viewModel.selection.count == 1, let tableView else { return }
            let items = viewModel.sortedItems
            guard let idx = items.firstIndex(where: { viewModel.selection.contains($0.url) }) else { return }
            let nameColumnIndex = tableView.column(withIdentifier: .name)
            guard nameColumnIndex >= 0 else { return }
            tableView.editColumn(nameColumnIndex, row: idx, with: nil, select: true)
        }

        // MARK: - Context menu

        func buildContextMenu(for row: Int?) -> NSMenu {
            let menu = NSMenu()
            if let row, row < viewModel.sortedItems.count {
                let item = viewModel.sortedItems[row]
                let openItem = menu.addItem(withTitle: item.isDirectory ? "Открыть" : "Открыть", action: #selector(openContextItem), keyEquivalent: "")
                openItem.target = self

                let terminalItem = NSMenuItem(title: "Терминал", action: nil, keyEquivalent: "")
                let terminalSubmenu = NSMenu()
                let terminalDirectory = item.isDirectory ? item.url : item.url.deletingLastPathComponent()
                let newWindowItem = terminalSubmenu.addItem(withTitle: "Новое окно", action: #selector(openTerminalWindowAction(_:)), keyEquivalent: "")
                newWindowItem.target = self
                newWindowItem.representedObject = terminalDirectory
                let newTabItem = terminalSubmenu.addItem(withTitle: "Новая вкладка", action: #selector(openTerminalTabAction(_:)), keyEquivalent: "")
                newTabItem.target = self
                newTabItem.representedObject = terminalDirectory
                terminalItem.submenu = terminalSubmenu
                menu.addItem(terminalItem)

                if item.isDirectory {
                    let alreadyFavorite = favoritesStore.contains(item.url)
                    let favoriteItem = menu.addItem(
                        withTitle: alreadyFavorite ? "Уже в избранном" : "Добавить в избранное",
                        action: alreadyFavorite ? nil : #selector(addFavoriteContextAction(_:)),
                        keyEquivalent: ""
                    )
                    favoriteItem.target = self
                    favoriteItem.isEnabled = !alreadyFavorite
                    favoriteItem.representedObject = item.url
                }
                menu.addItem(.separator())

                let cutItem = menu.addItem(withTitle: "Вырезать", action: #selector(cutContextAction), keyEquivalent: "")
                cutItem.target = self
                let copyItem = menu.addItem(withTitle: "Копировать", action: #selector(copyContextAction), keyEquivalent: "")
                copyItem.target = self
                if ClipboardService.canPaste {
                    let pasteItem = menu.addItem(withTitle: "Вставить", action: #selector(pasteContextAction), keyEquivalent: "")
                    pasteItem.target = self
                }
                menu.addItem(.separator())

                let renameItem = menu.addItem(withTitle: "Переименовать", action: #selector(renameContextAction), keyEquivalent: "")
                renameItem.target = self
                renameItem.isEnabled = viewModel.selection.count == 1
                menu.addItem(.separator())

                let deleteItem = menu.addItem(withTitle: "Удалить", action: #selector(deleteContextAction), keyEquivalent: "")
                deleteItem.target = self
                menu.addItem(.separator())

                let infoItem = menu.addItem(withTitle: "Свойства", action: #selector(propertiesContextAction), keyEquivalent: "")
                infoItem.target = self
            } else {
                let newFolderItem = menu.addItem(withTitle: "Новая папка", action: #selector(newFolderContextAction), keyEquivalent: "")
                newFolderItem.target = self

                let terminalItem = NSMenuItem(title: "Терминал", action: nil, keyEquivalent: "")
                let terminalSubmenu = NSMenu()
                let newWindowItem = terminalSubmenu.addItem(withTitle: "Новое окно", action: #selector(openTerminalWindowAction(_:)), keyEquivalent: "")
                newWindowItem.target = self
                newWindowItem.representedObject = currentDirectory
                let newTabItem = terminalSubmenu.addItem(withTitle: "Новая вкладка", action: #selector(openTerminalTabAction(_:)), keyEquivalent: "")
                newTabItem.target = self
                newTabItem.representedObject = currentDirectory
                terminalItem.submenu = terminalSubmenu
                menu.addItem(terminalItem)

                if ClipboardService.canPaste {
                    let pasteItem = menu.addItem(withTitle: "Вставить", action: #selector(pasteContextAction), keyEquivalent: "")
                    pasteItem.target = self
                }
            }
            return menu
        }

        @objc private func openContextItem() {
            guard let item = viewModel.selectedItems.first else { return }
            if item.isDirectory { onNavigate(item.url) } else { onOpenFile(item.url) }
        }

        @objc private func cutContextAction() { cutSelected() }
        @objc private func copyContextAction() { copySelected() }
        @objc private func pasteContextAction() { pasteIntoCurrent() }
        @objc private func deleteContextAction() { deleteSelected() }
        @objc private func renameContextAction() { startRenameSelected() }
        @objc private func propertiesContextAction() { onShowProperties(viewModel.selectedItems) }
        @objc private func newFolderContextAction() { viewModel.performNewFolder(in: currentDirectory) }

        @objc private func addFavoriteContextAction(_ sender: NSMenuItem) {
            guard let url = sender.representedObject as? URL else { return }
            favoritesStore.add(url)
        }

        @objc private func openTerminalWindowAction(_ sender: NSMenuItem) {
            guard let url = sender.representedObject as? URL else { return }
            TerminalService.openNewWindow(at: url)
        }

        @objc private func openTerminalTabAction(_ sender: NSMenuItem) {
            guard let url = sender.representedObject as? URL else { return }
            TerminalService.openNewTab(at: url)
        }
    }
}
