import SwiftUI
import UniformTypeIdentifiers

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
            if Self.isProbablyText(item.url) {
                TextFilePreviewView(url: item.url)
            } else {
                QuickLookPreview(url: item.url)
            }
        } else if let item = singleSelected, item.isDirectory {
            FolderPreviewView(item: item)
        } else {
            PreviewEmptyState()
        }
    }

    /// QuickLook's built-in text generator only kicks in for extensions
    /// registered with a `public.text`-conforming UTI. Plenty of legitimate
    /// source/text files (`.cs`, `.csproj`, …) aren't registered that way
    /// and show a blank "no preview" state instead of their contents, so
    /// sniff the file itself as a fallback: no extension check needed for
    /// known text types (QuickLook already handles those), only for the
    /// rest — no NUL byte and valid as UTF-8 in a small sample means text.
    private static func isProbablyText(_ url: URL) -> Bool {
        if let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .text) {
            return false // let QuickLook's native renderer handle these
        }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let sample = try? handle.read(upToCount: 4096), !sample.isEmpty else { return false }
        guard !sample.contains(0) else { return false }
        return String(data: sample, encoding: .utf8) != nil
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
