import Foundation
import Observation

enum SortColumn: String {
    case name, dateModified, kind, size
}

@Observable
final class FileListViewModel {
    private(set) var items: [FileSystemItem] = []
    var sortColumn: SortColumn = .name
    var sortAscending: Bool = true
    var selection: Set<URL> = []
    var errorMessage: String?

    var sortedItems: [FileSystemItem] {
        let sorted = items.sorted { lhs, rhs in
            // Folders before files, matching Windows Explorer default grouping.
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory && !rhs.isDirectory }
            switch sortColumn {
            case .name:
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .dateModified:
                return (lhs.modificationDate ?? .distantPast) < (rhs.modificationDate ?? .distantPast)
            case .kind:
                return lhs.kindDescription.localizedStandardCompare(rhs.kindDescription) == .orderedAscending
            case .size:
                return (lhs.size ?? 0) < (rhs.size ?? 0)
            }
        }
        return sortAscending ? sorted : sorted.reversed()
    }

    func reload(directory: URL) {
        do {
            items = try FileSystemService.contents(of: directory)
            errorMessage = nil
        } catch {
            items = []
            errorMessage = error.localizedDescription
        }
        selection.removeAll()
    }

    var selectedItems: [FileSystemItem] {
        items.filter { selection.contains($0.url) }
    }

    var selectedSizeDescription: String? {
        guard !selection.isEmpty else { return nil }
        let total = selectedItems.reduce(Int64(0)) { $0 + ($1.size ?? 0) }
        return FileSizeFormatter.string(from: total)
    }

    // MARK: - File operations
    //
    // These back both the keyboard shortcuts (handled in FileTableView's
    // ExplorerTableView) and the context menu / command bar buttons, so the
    // two never drift out of sync.

    func performNewFolder(in directory: URL) {
        do {
            let created = try FileOperationsService.createFolder(in: directory)
            reload(directory: directory)
            selection = [created]
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func performRename(_ url: URL, to newName: String, in directory: URL) {
        do {
            let renamed = try FileOperationsService.rename(url, to: newName)
            reload(directory: directory)
            selection = [renamed]
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func performDelete(_ urls: [URL], in directory: URL) {
        guard !urls.isEmpty else { return }
        do {
            try FileOperationsService.moveToTrash(urls)
            reload(directory: directory)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func performCopy(_ urls: [URL]) {
        ClipboardService.copy(urls)
    }

    func performCut(_ urls: [URL]) {
        ClipboardService.cut(urls)
    }

    func performPaste(in directory: URL) {
        guard let contents = ClipboardService.pasteboardContents() else { return }
        do {
            if contents.isCut {
                try FileOperationsService.moveItems(contents.urls, to: directory)
                ClipboardService.clear()
            } else {
                try FileOperationsService.copyItems(contents.urls, to: directory)
            }
            reload(directory: directory)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Backs drag-and-drop from Finder, from within the app's own file list,
    /// or onto a sidebar row — `directory` is wherever the drop landed
    /// (a folder row, a sidebar favorite, or the current folder's background).
    func performDrop(urls: [URL], into directory: URL, move: Bool, currentDirectory: URL) {
        guard !urls.isEmpty else { return }
        do {
            if move {
                try FileOperationsService.moveItems(urls, to: directory)
            } else {
                try FileOperationsService.copyItems(urls, to: directory)
            }
            if directory.standardizedFileURL == currentDirectory.standardizedFileURL {
                reload(directory: currentDirectory)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
