import Foundation

struct Volume: Identifiable, Hashable {
    let url: URL
    let name: String
    let isRemovable: Bool
    let isEjectable: Bool

    var id: URL { url }
}
