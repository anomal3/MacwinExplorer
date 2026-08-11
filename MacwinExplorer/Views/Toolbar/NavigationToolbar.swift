import SwiftUI

struct NavigationToolbar: View {
    let navigation: NavigationViewModel
    var onBack: () -> Void
    var onForward: () -> Void
    var onUp: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
            }
            .disabled(!navigation.canGoBack)
            .help("Назад")

            Button(action: onForward) {
                Image(systemName: "chevron.right")
            }
            .disabled(!navigation.canGoForward)
            .help("Вперёд")

            Button(action: onUp) {
                Image(systemName: "chevron.up")
            }
            .disabled(!navigation.canGoUp)
            .help("Вверх")
        }
        .buttonStyle(.borderless)
    }
}
