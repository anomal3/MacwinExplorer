import Foundation

enum FileOperationsService {

    @discardableResult
    static func createFolder(in directory: URL, baseName: String = "Новая папка") throws -> URL {
        let destination = uniqueDestination(baseName: baseName, extension: "", in: directory)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        return destination
    }

    @discardableResult
    static func rename(_ url: URL, to newName: String) throws -> URL {
        let destination = url.deletingLastPathComponent().appendingPathComponent(newName)
        guard destination.path != url.path else { return url }
        try FileManager.default.moveItem(at: url, to: destination)
        return destination
    }

    static func moveToTrash(_ urls: [URL]) throws {
        for url in urls {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
    }

    static func copyItems(_ urls: [URL], to directory: URL) throws {
        for url in urls {
            guard url.deletingLastPathComponent() != directory else { continue }
            let destination = uniqueDestination(for: url, in: directory)
            try FileManager.default.copyItem(at: url, to: destination)
        }
    }

    static func moveItems(_ urls: [URL], to directory: URL) throws {
        for url in urls {
            guard url.deletingLastPathComponent() != directory else { continue }
            let destination = uniqueDestination(for: url, in: directory)
            try FileManager.default.moveItem(at: url, to: destination)
        }
    }

    private static func uniqueDestination(for sourceURL: URL, in directory: URL) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension
        return uniqueDestination(baseName: baseName, extension: ext, in: directory)
    }

    private static func uniqueDestination(baseName: String, extension ext: String, in directory: URL) -> URL {
        func candidateName(_ suffix: Int?) -> String {
            let name = suffix.map { "\(baseName) \($0)" } ?? baseName
            return ext.isEmpty ? name : "\(name).\(ext)"
        }
        var suffix: Int?
        var candidate = directory.appendingPathComponent(candidateName(suffix))
        while FileManager.default.fileExists(atPath: candidate.path) {
            suffix = (suffix ?? 1) + 1
            candidate = directory.appendingPathComponent(candidateName(suffix))
        }
        return candidate
    }
}
