import SwiftUI

/// 2 MB cap on read text preview content, so huge logs don't hang the UI.
private let textPreviewSizeCap = 2_000_000

/// Renders a file's contents as plain text — used for source/text files
/// whose extension isn't registered with a `public.text`-conforming UTI
/// (e.g. `.cs`, `.csproj`), which QuickLook's built-in generators skip,
/// showing a blank "no preview" state instead of the text.
struct TextFilePreviewView: View {
    let url: URL

    @State private var text: String?
    @State private var failed = false

    var body: some View {
        Group {
            if let text {
                ScrollView {
                    Text(text)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
            } else if failed {
                PreviewUnavailableView()
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: url) {
            text = nil
            failed = false
            let loaded = await Self.loadText(from: url)
            text = loaded
            failed = loaded == nil
        }
    }

    private static func loadText(from url: URL) async -> String? {
        await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else { return nil }
            let capped = data.prefix(textPreviewSizeCap)
            return String(data: capped, encoding: .utf8) ?? String(data: capped, encoding: .isoLatin1)
        }.value
    }
}

private struct PreviewUnavailableView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Предпросмотр недоступен")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
