import Foundation

struct FavoriteItem: Identifiable, Hashable, Codable {
    let id: UUID
    var url: URL
    var displayName: String

    init(id: UUID = UUID(), url: URL, displayName: String? = nil) {
        self.id = id
        self.url = url
        self.displayName = displayName ?? url.lastPathComponent
    }
}
