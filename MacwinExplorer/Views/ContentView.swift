import SwiftUI
import AppKit

struct ContentView: View {
    @State private var navigation = NavigationViewModel()
    @State private var sidebar = SidebarViewModel()
    @State private var fileList = FileListViewModel()
    @State private var propertiesRequest: PropertiesRequest?
    @State private var renameRequested = false
    @State private var showFDAGuide = false

    @AppStorage(SettingsKeys.showPreviewPane) private var showPreviewPane = true
    @AppStorage(SettingsKeys.showCommandBar) private var showCommandBar = true
    @AppStorage(SettingsKeys.commandBarStyle) private var commandBarStyle: CommandBarStyle = .iconAndText
    @AppStorage(SettingsKeys.dontShowFDAGuide) private var dontShowFDAGuide = false

    var body: some View {
        NavigationSplitView {
            SidebarOutlineView(viewModel: sidebar) { url in
                navigate(to: url)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        NavigationToolbar(
                            navigation: navigation,
                            onBack: { navigation.goBack(); reloadCurrentDirectory() },
                            onForward: { navigation.goForward(); reloadCurrentDirectory() },
                            onUp: { navigation.goUp(); reloadCurrentDirectory() }
                        )
                        PathBreadcrumbView(navigation: navigation) { url in
                            navigate(to: url)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                    if showCommandBar {
                        CommandBarView(
                            style: commandBarStyle,
                            hasSelection: !fileList.selection.isEmpty,
                            singleSelection: fileList.selection.count == 1,
                            canPaste: ClipboardService.canPaste,
                            isPreviewShown: showPreviewPane,
                            onNewFolder: { fileList.performNewFolder(in: navigation.currentURL) },
                            onCut: { fileList.performCut(Array(fileList.selection)) },
                            onCopy: { fileList.performCopy(Array(fileList.selection)) },
                            onPaste: { fileList.performPaste(in: navigation.currentURL) },
                            onRename: { renameRequested = true },
                            onDelete: { fileList.performDelete(Array(fileList.selection), in: navigation.currentURL) },
                            onProperties: { showProperties(for: fileList.selectedItems) },
                            onTogglePreview: { showPreviewPane.toggle() }
                        )
                    }

                    FileTableView(
                        viewModel: fileList,
                        currentDirectory: navigation.currentURL,
                        renameRequested: $renameRequested,
                        onNavigate: { url in navigate(to: url) },
                        onOpenFile: { url in NSWorkspace.shared.open(url) },
                        onShowProperties: { items in showProperties(for: items) }
                    )

                    StatusBarView(fileList: fileList, currentDirectory: navigation.currentURL)
                }
                .frame(maxWidth: .infinity)

                if showPreviewPane {
                    Divider()
                    PreviewPaneView(
                        currentDirectory: navigation.currentURL,
                        selectedItems: fileList.selectedItems,
                        onClose: { showPreviewPane = false }
                    )
                    .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)
                }
            }
        }
        .onAppear {
            sidebar.reload()
            reloadCurrentDirectory()
            if !dontShowFDAGuide && !PermissionsService.hasFullDiskAccess() {
                showFDAGuide = true
            }
        }
        .sheet(isPresented: $showFDAGuide) {
            FullDiskAccessGuideView()
        }
        .alert(
            "Ошибка",
            isPresented: Binding(
                get: { fileList.errorMessage != nil },
                set: { if !$0 { fileList.errorMessage = nil } }
            )
        ) {
            Button("ОК", role: .cancel) { fileList.errorMessage = nil }
        } message: {
            Text(fileList.errorMessage ?? "")
        }
        .sheet(item: $propertiesRequest) { request in
            PropertiesView(items: request.items)
        }
        .background(
            Group {
                Button("") { fileList.performNewFolder(in: navigation.currentURL) }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("") { showProperties(for: fileList.selectedItems) }
                    .keyboardShortcut("i", modifiers: .command)
                Button("") { showPreviewPane.toggle() }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
            }
            .opacity(0)
            .allowsHitTesting(false)
        )
    }

    private func navigate(to url: URL) {
        navigation.navigate(to: url)
        reloadCurrentDirectory()
    }

    private func reloadCurrentDirectory() {
        fileList.reload(directory: navigation.currentURL)
    }

    private func showProperties(for items: [FileSystemItem]) {
        guard !items.isEmpty else { return }
        propertiesRequest = PropertiesRequest(items: items)
    }
}

#Preview {
    ContentView()
}
