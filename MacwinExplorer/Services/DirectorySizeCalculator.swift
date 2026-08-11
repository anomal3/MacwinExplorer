import Foundation

enum DirectorySizeCalculator {
    /// Recursively sums file sizes for a folder, or just returns the size for a plain file.
    static func size(of url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
        guard values?.isDirectory == true else {
            return Int64(values?.fileSize ?? 0)
        }
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let v = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]), v.isDirectory != true else { continue }
            total += Int64(v.fileSize ?? 0)
        }
        return total
    }
}
