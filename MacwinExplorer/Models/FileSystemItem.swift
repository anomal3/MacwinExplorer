import Foundation
import AppKit

struct FileSystemItem: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    let size: Int64?
    let modificationDate: Date?
    let creationDate: Date?
    let kindDescription: String

    var id: URL { url }
    var name: String { url.lastPathComponent }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    static func == (lhs: FileSystemItem, rhs: FileSystemItem) -> Bool { lhs.url == rhs.url }
    func hash(into hasher: inout Hasher) { hasher.combine(url) }
}
