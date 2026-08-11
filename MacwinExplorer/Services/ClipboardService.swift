import AppKit

/// Thin wrapper over NSPasteboard for file cut/copy/paste. Stateless — the
/// system pasteboard is the single source of truth, marked with a private
/// type when the last write was a "cut" so paste knows to move instead of copy.
enum ClipboardService {
    private static let cutMarkerType = NSPasteboard.PasteboardType("com.macwinexplorer.cut")

    static func copy(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(urls as [NSURL])
    }

    static func cut(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(urls as [NSURL])
        pb.setString("1", forType: cutMarkerType)
    }

    static var canPaste: Bool {
        NSPasteboard.general.canReadObject(forClasses: [NSURL.self], options: nil)
    }

    static func pasteboardContents() -> (urls: [URL], isCut: Bool)? {
        let pb = NSPasteboard.general
        guard let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty else {
            return nil
        }
        let isCut = pb.data(forType: cutMarkerType) != nil
        return (urls, isCut)
    }

    static func clear() {
        NSPasteboard.general.clearContents()
    }
}
