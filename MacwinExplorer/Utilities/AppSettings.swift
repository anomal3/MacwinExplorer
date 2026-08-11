import Foundation

enum SettingsKeys {
    static let showPreviewPane = "showPreviewPane"
    static let showCommandBar = "showCommandBar"
    static let commandBarStyle = "commandBarStyle"
}

/// Mirrors the three options macOS's own toolbar customization sheet offers.
enum CommandBarStyle: String, CaseIterable, Identifiable {
    case iconAndText
    case iconOnly
    case textOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .iconAndText: return "Иконки и текст"
        case .iconOnly: return "Только иконки"
        case .textOnly: return "Только текст"
        }
    }
}
