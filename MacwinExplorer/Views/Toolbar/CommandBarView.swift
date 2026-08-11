import SwiftUI

/// The command "navbar": duplicates the context-menu / keyboard-shortcut
/// actions as buttons, so nothing requires memorizing a hotkey. Its
/// visibility and icon/text style are controlled from Settings.
struct CommandBarView: View {
    let style: CommandBarStyle
    let hasSelection: Bool
    let singleSelection: Bool
    let canPaste: Bool
    let isPreviewShown: Bool

    var onNewFolder: () -> Void
    var onCut: () -> Void
    var onCopy: () -> Void
    var onPaste: () -> Void
    var onRename: () -> Void
    var onDelete: () -> Void
    var onProperties: () -> Void
    var onTogglePreview: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Scrolls instead of wrapping button labels onto multiple lines
            // when the window (or the preview pane) leaves little room.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    commandButton("Новая папка", "folder.badge.plus", action: onNewFolder)
                    Divider().frame(height: 16)
                    commandButton("Вырезать", "scissors", action: onCut).disabled(!hasSelection)
                    commandButton("Копировать", "doc.on.doc", action: onCopy).disabled(!hasSelection)
                    commandButton("Вставить", "doc.on.clipboard", action: onPaste).disabled(!canPaste)
                    Divider().frame(height: 16)
                    commandButton("Переименовать", "pencil", action: onRename).disabled(!singleSelection)
                    commandButton("Удалить", "trash", action: onDelete).disabled(!hasSelection)
                    Divider().frame(height: 16)
                    commandButton("Свойства", "info.circle", action: onProperties).disabled(!hasSelection)
                }
            }
            Spacer(minLength: 8)
            commandButton(
                isPreviewShown ? "Скрыть предпросмотр" : "Показать предпросмотр",
                "sidebar.right",
                action: onTogglePreview
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(nsColor: .separatorColor)).frame(height: 1)
        }
    }

    @ViewBuilder
    private func commandButton(_ title: String, _ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            switch style {
            case .iconAndText:
                Label(title, systemImage: systemImage)
                    .lineLimit(1)
                    .fixedSize()
            case .iconOnly:
                Image(systemName: systemImage)
            case .textOnly:
                Text(title)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .buttonStyle(.borderless)
        .help(title)
    }
}
