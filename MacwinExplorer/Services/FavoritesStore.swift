import Foundation
import Observation

/// User-editable "Избранное" list, persisted to UserDefaults. Seeded once
/// with the standard Windows-Explorer-style quick-access folders plus
/// Pictures, iCloud Drive (if present), and Applications.
@Observable
final class FavoritesStore {
    private(set) var items: [FavoriteItem] = []
    private let storageKey = "favoriteItems"

    init() {
        load()
        if items.isEmpty {
            seedDefaults()
        }
    }

    func add(_ url: URL, displayName: String? = nil) {
        guard !contains(url) else { return }
        items.append(FavoriteItem(url: url, displayName: displayName))
        save()
    }

    func remove(_ item: FavoriteItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func contains(_ url: URL) -> Bool {
        let standardized = url.standardizedFileURL
        return items.contains { $0.url.standardizedFileURL == standardized }
    }

    private func seedDefaults() {
        let fm = FileManager.default
        var defaults: [FavoriteItem] = [
            FavoriteItem(url: fm.homeDirectoryForCurrentUser)
        ]

        let searchPaths: [(FileManager.SearchPathDirectory, String)] = [
            (.desktopDirectory, "Desktop"),
            (.documentDirectory, "Documents"),
            (.downloadsDirectory, "Downloads"),
            (.picturesDirectory, "Фото")
        ]
        for (directory, name) in searchPaths {
            if let url = fm.urls(for: directory, in: .userDomainMask).first {
                defaults.append(FavoriteItem(url: url, displayName: name))
            }
        }

        let iCloudDriveURL = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        if fm.fileExists(atPath: iCloudDriveURL.path) {
            defaults.append(FavoriteItem(url: iCloudDriveURL, displayName: "iCloud Drive"))
        }

        defaults.append(FavoriteItem(url: URL(fileURLWithPath: "/Applications"), displayName: "Программы"))

        items = defaults
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([FavoriteItem].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
