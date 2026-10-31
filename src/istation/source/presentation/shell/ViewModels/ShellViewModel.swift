import BusinessLibrary
import DataCatalog
import Foundation
import Observation

/// A place in the sidebar: the shell's route.
public enum SidebarItem: Hashable, Sendable {
    case all
    case recent
    case platform(Platform)
}

/// The main window's chrome: which place is showing, the search field, the toolbar's actions and
/// the error alert.
@MainActor
@Observable
public final class ShellViewModel {
    /// The selected sidebar place; nil only while the sidebar has no selection.
    public var route: SidebarItem? = .all
    public var search = ""
    /// True while the folder chooser is showing.
    public var isChoosingFolders = false

    private let library: Library

    public init(library: Library) {
        self.library = library
    }

    public var platforms: [Platform] { Platform.allCases }
    public var gameCount: Int { library.games.count }
    public func gameCount(for platform: Platform) -> Int { library.count(of: platform) }
    public var isScanning: Bool { library.isScanning }
    public var errorMessage: String? { library.lastError }

    public var title: String {
        switch route ?? .all {
        case .all: "All Games"
        case .recent: "Recently Played"
        case .platform(let platform): platform.displayName
        }
    }

    /// The library query for the place that is showing.
    public var filter: LibraryFilter {
        switch route ?? .all {
        case .all: .all
        case .recent: .recent
        case .platform(let platform): .platform(platform)
        }
    }

    public func chooseFolders() {
        isChoosingFolders = true
    }

    public func addFolders(_ urls: [URL]) async {
        await library.addFolders(urls)
    }

    public func rescan() async {
        await library.rescan()
    }

    public func dismissError() {
        library.dismissError()
    }
}
