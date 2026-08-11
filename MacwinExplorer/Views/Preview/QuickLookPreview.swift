import SwiftUI
import Quartz

/// Wraps QLPreviewView so the app gets Finder-grade previews (PDF, images,
/// Word/Excel/PowerPoint, and plain/source-text files of any extension) for
/// free, instead of hand-rolling a renderer per file type.
struct QuickLookPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        // This failable initializer does not fail in practice for .normal style.
        let view = QLPreviewView(frame: .zero, style: .normal)!
        view.autostarts = true
        view.previewItem = url as QLPreviewItem
        return view
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        nsView.previewItem = url as QLPreviewItem
    }
}
