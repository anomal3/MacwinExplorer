import SwiftUI

/// Right-hand preview pane, toggled from Settings, the command bar button,
/// or its own close button — mirrors Windows Explorer's preview pane.
struct PreviewPaneView: View {
    let currentDirectory: URL
    let selectedItems: [FileSystemItem]
    var onClose: () -> Void

    private var singleSelected: FileSystemItem? {
        selectedItems.count == 1 ? selectedItems.first : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Предпросмотр")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Скрыть предпросмотр")
            }
            .padding(10)

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private var content: some View {
        if let item = singleSelected, FileSystemService.isVolumeRoot(item.url) {
            VolumeUsagePreviewView(url: item.url)
        } else if selectedItems.isEmpty, FileSystemService.isVolumeRoot(currentDirectory) {
            VolumeUsagePreviewView(url: currentDirectory)
        } else if let item = singleSelected, !item.isDirectory {
            QuickLookPreview(url: item.url)
        } else if let item = singleSelected, item.isDirectory {
            FolderPreviewView(item: item)
        } else {
            PreviewEmptyState()
        }
    }
}

private struct PreviewEmptyState: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Выберите файл или диск")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
