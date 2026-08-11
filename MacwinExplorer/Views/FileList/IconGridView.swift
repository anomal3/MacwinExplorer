import SwiftUI
import AppKit

/// The "Large icons" view mode — a SwiftUI grid alternative to the
/// NSTableView-based details list. Shares the same FileListViewModel
/// (selection, sorting, operations), so switching modes never loses state.
struct IconGridView: View {
    let viewModel: FileListViewModel
    let favoritesStore: FavoritesStore
    var currentDirectory: URL
    var onNavigate: (URL) -> Void
    var onOpenFile: (URL) -> Void
    var onShowProperties: ([FileSystemItem]) -> Void

    @State private var renamingItem: FileSystemItem?
    @State private var renameText = ""

    private let columns = [GridItem(.adaptive(minimum: 96, maximum: 120), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(viewModel.sortedItems) { item in
                    cell(for: item)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(
            Color(nsColor: .textBackgroundColor)
                .onTapGesture { viewModel.selection.removeAll() }
        )
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers, into: currentDirectory)
            return true
        }
        .alert(
            "Переименовать",
            isPresented: Binding(get: { renamingItem != nil }, set: { if !$0 { renamingItem = nil } })
        ) {
            TextField("Имя", text: $renameText)
            Button("Отмена", role: .cancel) { renamingItem = nil }
            Button("Готово") {
                if let item = renamingItem {
                    viewModel.performRename(item.url, to: renameText, in: currentDirectory)
                }
                renamingItem = nil
            }
        }
    }

    @ViewBuilder
    private func cell(for item: FileSystemItem) -> some View {
        IconGridCell(item: item, isSelected: viewModel.selection.contains(item.url))
            .onTapGesture(count: 2) { openOrNavigate(item) }
            .simultaneousGesture(TapGesture().onEnded { handleSingleClick(item) })
            .contextMenu { contextMenuContent(for: item) }
            .onDrag { NSItemProvider(object: item.url as NSURL) }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers, into: item.isDirectory ? item.url : currentDirectory)
                return true
            }
    }

    private func openOrNavigate(_ item: FileSystemItem) {
        if item.isDirectory { onNavigate(item.url) } else { onOpenFile(item.url) }
    }

    private func handleDrop(providers: [NSItemProvider], into directory: URL) {
        var collected: [URL] = []
        let group = DispatchGroup()
        for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                DispatchQueue.main.async {
                    if let url { collected.append(url) }
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) {
            guard !collected.isEmpty else { return }
            let move = DragDropDefaultAction.resolved() == .move
            viewModel.performDrop(urls: collected, into: directory, move: move, currentDirectory: currentDirectory)
        }
    }

    private func handleSingleClick(_ item: FileSystemItem) {
        if NSEvent.modifierFlags.contains(.command) {
            if viewModel.selection.contains(item.url) {
                viewModel.selection.remove(item.url)
            } else {
                viewModel.selection.insert(item.url)
            }
        } else {
            viewModel.selection = [item.url]
        }
    }

    @ViewBuilder
    private func contextMenuContent(for item: FileSystemItem) -> some View {
        let items = viewModel.selection.contains(item.url) ? viewModel.selectedItems : [item]
        let urls = items.map(\.url)
        let terminalDirectory = item.isDirectory ? item.url : item.url.deletingLastPathComponent()

        Button("Открыть") {
            if item.isDirectory { onNavigate(item.url) } else { onOpenFile(item.url) }
        }
        Menu("Терминал") {
            Button("Новое окно") { TerminalService.openNewWindow(at: terminalDirectory) }
            Button("Новая вкладка") { TerminalService.openNewTab(at: terminalDirectory) }
        }
        if item.isDirectory {
            if favoritesStore.contains(item.url) {
                Text("Уже в избранном")
            } else {
                Button("Добавить в избранное") { favoritesStore.add(item.url) }
            }
        }
        Divider()
        Button("Вырезать") { viewModel.performCut(urls) }
        Button("Копировать") { viewModel.performCopy(urls) }
        if ClipboardService.canPaste {
            Button("Вставить") { viewModel.performPaste(in: currentDirectory) }
        }
        Divider()
        Button("Переименовать") {
            renamingItem = item
            renameText = item.name
        }
        .disabled(items.count != 1)
        Divider()
        Button("Удалить") { viewModel.performDelete(urls, in: currentDirectory) }
        Divider()
        Button("Свойства") { onShowProperties(items) }
    }
}

private struct IconGridCell: View {
    let item: FileSystemItem
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 48, height: 48)
            Text(item.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 90)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.accentColor.opacity(0.25) : Color.clear))
        .contentShape(Rectangle())
    }
}
