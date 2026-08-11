import SwiftUI
import AppKit

struct ContentView: View {
    let favoritesStore: FavoritesStore
    let networkSharesStore: NetworkSharesStore

    @State private var navigation = NavigationViewModel()
    @State private var sidebar: SidebarViewModel
    @State private var fileList = FileListViewModel()
    @State private var propertiesRequest: PropertiesRequest?
    @State private var renameRequested = false
    @State private var showFDAGuide = false
    @State private var showConnectNetworkShare = false

    @AppStorage(SettingsKeys.showPreviewPane) private var showPreviewPane = true
    @AppStorage(SettingsKeys.showCommandBar) private var showCommandBar = true
    @AppStorage(SettingsKeys.commandBarStyle) private var commandBarStyle: CommandBarStyle = .iconAndText
    @AppStorage(SettingsKeys.dontShowFDAGuide) private var dontShowFDAGuide = false
    @AppStorage(SettingsKeys.fileViewMode) private var viewMode: FileViewMode = .details

    @Environment(\.openWindow) private var openWindow

    init(favoritesStore: FavoritesStore, networkSharesStore: NetworkSharesStore) {
        self.favoritesStore = favoritesStore
        self.networkSharesStore = networkSharesStore
        _sidebar = State(initialValue: SidebarViewModel(favoritesStore: favoritesStore, networkSharesStore: networkSharesStore))
    }

    var body: some View {
        NavigationSplitView {
            SidebarOutlineView(
                viewModel: sidebar,
                onSelect: { url in navigate(to: url) },
                onConnectNetworkShare: { showConnectNetworkShare = true },
                onDropFiles: { urls, destination, move in
                    fileList.performDrop(urls: urls, into: destination, move: move, currentDirectory: navigation.currentURL)
                }
            )
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

                    Group {
                        switch viewMode {
                        case .details:
                            FileTableView(
                                viewModel: fileList,
                                favoritesStore: favoritesStore,
                                currentDirectory: navigation.currentURL,
                                renameRequested: $renameRequested,
                                onNavigate: { url in navigate(to: url) },
                                onOpenFile: { url in NSWorkspace.shared.open(url) },
                                onShowProperties: { items in showProperties(for: items) }
                            )
                        case .icons:
                            IconGridView(
                                viewModel: fileList,
                                favoritesStore: favoritesStore,
                                currentDirectory: navigation.currentURL,
                                onNavigate: { url in navigate(to: url) },
                                onOpenFile: { url in NSWorkspace.shared.open(url) },
                                onShowProperties: { items in showProperties(for: items) }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    StatusBarView(fileList: fileList, currentDirectory: navigation.currentURL, viewMode: $viewMode)
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
            networkSharesStore.reconnectAutoMountShares()
            if !dontShowFDAGuide && !PermissionsService.hasFullDiskAccess() {
                showFDAGuide = true
            }
            GlobalHotKeyService.shared.onTrigger = {
                openWindow(id: "main")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToFavorite)) { notification in
            guard let url = notification.object as? URL else { return }
            navigate(to: url)
        }
        .sheet(isPresented: $showFDAGuide) {
            FullDiskAccessGuideView()
        }
        .sheet(isPresented: $showConnectNetworkShare) {
            ConnectNetworkShareView(networkSharesStore: networkSharesStore) { mountedURL in
                sidebar.reload()
                navigate(to: mountedURL)
            }
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
    ContentView(favoritesStore: FavoritesStore(), networkSharesStore: NetworkSharesStore())
}
