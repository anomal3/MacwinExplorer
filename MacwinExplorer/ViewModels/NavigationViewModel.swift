import Foundation
import Observation

@Observable
final class NavigationViewModel {
    private(set) var currentURL: URL
    private(set) var backStack: [URL] = []
    private(set) var forwardStack: [URL] = []

    init(startURL: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.currentURL = startURL
    }

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }
    var canGoUp: Bool { currentURL.pathComponents.count > 1 }

    /// Breadcrumb segments from the volume root down to the current folder.
    ///
    /// Built from `pathComponents` rather than by repeatedly calling
    /// `deletingLastPathComponent()`, because that method does not treat "/"
    /// as a fixed point (it keeps appending "..") and would loop forever.
    var pathSegments: [(name: String, url: URL)] {
        let components = currentURL.standardizedFileURL.pathComponents
        var url = URL(fileURLWithPath: "/")
        var segments: [(name: String, url: URL)] = [(FileManager.default.displayName(atPath: "/"), url)]
        for component in components.dropFirst() {
            url.appendPathComponent(component)
            segments.append((FileManager.default.displayName(atPath: url.path), url))
        }
        return segments
    }

    func navigate(to url: URL, recordHistory: Bool = true) {
        guard url != currentURL else { return }
        if recordHistory {
            backStack.append(currentURL)
            forwardStack.removeAll()
        }
        currentURL = url
    }

    func goBack() {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(currentURL)
        currentURL = previous
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(currentURL)
        currentURL = next
    }

    func goUp() {
        guard canGoUp else { return }
        navigate(to: currentURL.deletingLastPathComponent())
    }
}
