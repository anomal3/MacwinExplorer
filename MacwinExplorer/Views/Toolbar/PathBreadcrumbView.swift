import SwiftUI

struct PathBreadcrumbView: View {
    let navigation: NavigationViewModel
    var onNavigate: (URL) -> Void

    @State private var isEditingPath = false
    @State private var editedPath: String = ""
    @FocusState private var pathFieldFocused: Bool

    var body: some View {
        Group {
            if isEditingPath {
                TextField("Путь", text: $editedPath, onCommit: commitEditedPath)
                    .textFieldStyle(.roundedBorder)
                    .focused($pathFieldFocused)
                    .onExitCommand { isEditingPath = false }
                    .onAppear {
                        editedPath = navigation.currentURL.path
                        pathFieldFocused = true
                    }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(navigation.pathSegments.enumerated()), id: \.offset) { index, segment in
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            Button(segment.name) { onNavigate(segment.url) }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(segment.url == navigation.currentURL ? Color.accentColor.opacity(0.15) : .clear)
                                )
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { isEditingPath = true }
            }
        }
        .frame(height: 26)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
    }

    private func commitEditedPath() {
        let expanded = (editedPath as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue {
            onNavigate(URL(fileURLWithPath: expanded))
        }
        isEditingPath = false
    }
}
