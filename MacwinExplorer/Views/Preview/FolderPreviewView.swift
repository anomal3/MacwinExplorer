import SwiftUI

/// Fallback preview for a selected regular folder (not a volume root) —
/// Quick Look has nothing meaningful to render for a directory, so show
/// its icon and item count instead.
struct FolderPreviewView: View {
    let item: FileSystemItem

    private var childCount: Int {
        (try? FileSystemService.contents(of: item.url).count) ?? 0
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 96, height: 96)
            Text(item.name)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Объектов: \(childCount)")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 30)
        .frame(maxWidth: .infinity)
    }
}
