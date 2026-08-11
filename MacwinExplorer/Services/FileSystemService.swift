import Foundation

enum FileSystemService {

    private static let resourceKeys: [URLResourceKey] = [
        .isDirectoryKey, .fileSizeKey, .contentModificationDateKey,
        .creationDateKey, .localizedTypeDescriptionKey, .isHiddenKey
    ]

    /// Lists the immediate contents of a directory.
    static func contents(of directory: URL, showHidden: Bool = false) throws -> [FileSystemItem] {
        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if !showHidden { options.insert(.skipsHiddenFiles) }

        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: resourceKeys,
            options: options
        )
        return urls.map(makeItem)
    }

    static func makeItem(for url: URL) -> FileSystemItem {
        let values = try? url.resourceValues(forKeys: Set(resourceKeys))
        let isDirectory = values?.isDirectory ?? false
        return FileSystemItem(
            url: url,
            isDirectory: isDirectory,
            size: isDirectory ? nil : values?.fileSize.map(Int64.init),
            modificationDate: values?.contentModificationDate,
            creationDate: values?.creationDate,
            kindDescription: values?.localizedTypeDescription ?? (isDirectory ? "Folder" : "Document")
        )
    }

    /// Only the subdirectories of a directory — used for lazy sidebar tree expansion.
    static func subdirectories(of directory: URL) -> [FileSystemItem] {
        (try? contents(of: directory))?.filter { $0.isDirectory } ?? []
    }

    static func mountedVolumes() -> [Volume] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey, .volumeIsEjectableKey]
        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) ?? []
        return urls.map { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            return Volume(
                url: url,
                name: values?.volumeName ?? url.lastPathComponent,
                isRemovable: values?.volumeIsRemovable ?? false,
                isEjectable: values?.volumeIsEjectable ?? false
            )
        }
    }

    /// Common Windows-Explorer-style "Quick access" shortcuts.
    static func favoriteLocations() -> [FileSystemItem] {
        let fm = FileManager.default
        let directories: [FileManager.SearchPathDirectory] = [.desktopDirectory, .documentDirectory, .downloadsDirectory]
        var items: [FileSystemItem] = [makeItem(for: fm.homeDirectoryForCurrentUser)]
        for directory in directories {
            if let url = fm.urls(for: directory, in: .userDomainMask).first {
                items.append(makeItem(for: url))
            }
        }
        return items
    }

    static func availableCapacity(for url: URL) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityKey])
        return values?.volumeAvailableCapacity.map(Int64.init)
    }

    struct VolumeUsage {
        let name: String
        let totalCapacity: Int64
        let availableCapacity: Int64
        var usedCapacity: Int64 { max(0, totalCapacity - availableCapacity) }
    }

    static func volumeUsage(for url: URL) -> VolumeUsage? {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey]
        guard let values = try? url.resourceValues(forKeys: Set(keys)),
              let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacity else { return nil }
        return VolumeUsage(
            name: values.volumeName ?? url.lastPathComponent,
            totalCapacity: Int64(total),
            availableCapacity: Int64(available)
        )
    }

    /// Whether `url` is the root of a mounted volume (an internal disk, or an
    /// external/removable one like a USB flash drive) rather than a regular folder.
    static func isVolumeRoot(_ url: URL) -> Bool {
        let standardizedPath = url.standardizedFileURL.path
        return mountedVolumes().contains { $0.url.standardizedFileURL.path == standardizedPath }
    }
}
