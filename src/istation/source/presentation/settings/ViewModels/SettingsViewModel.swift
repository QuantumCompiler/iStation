import BusinessLibrary
import DataCatalog
import DataEmulators
import Foundation
import Observation

/// One emulator's row in Settings.
public struct EmulatorRow: Identifiable, Equatable, Sendable {
    public let kind: EmulatorKind
    public var id: EmulatorKind { kind }
    /// "PCSX2 (PS2)"
    public let title: String
    /// The chosen app's path, or nil when none is set up.
    public let appPath: String?
}

/// The Settings window: emulator apps, launch options, library folders and RPCS3's installed games.
@MainActor
@Observable
public final class SettingsViewModel {
    /// True while the app chooser is showing.
    public var isChoosingApp = false
    /// True while the folder chooser is showing.
    public var isChoosingFolders = false
    /// The emulator the app chooser is choosing for. Kept after the chooser closes so its result lands.
    public private(set) var appChoiceKind: EmulatorKind?

    private let library: Library

    public init(library: Library) {
        self.library = library
    }

    // MARK: - Emulators

    public var emulators: [EmulatorRow] {
        EmulatorKind.allCases.map { kind in
            EmulatorRow(
                kind: kind,
                title: "\(kind.displayName) (\(kind.platform.shortName))",
                appPath: library.settings.app(for: kind)?.path
            )
        }
    }

    public func chooseApp(for kind: EmulatorKind) {
        appChoiceKind = kind
        isChoosingApp = true
    }

    public func useApp(_ url: URL) {
        guard let kind = appChoiceKind else { return }
        library.updateSettings { $0.setApp(url, for: kind) }
    }

    public func detectEmulators() {
        library.detectEmulators()
    }

    // MARK: - Launching

    public var startsFullscreen: Bool {
        get { library.settings.launchOptions.fullscreen }
        set { library.updateSettings { $0.launchOptions.fullscreen = newValue } }
    }

    public var skipsBIOSIntro: Bool {
        get { library.settings.launchOptions.fastBoot }
        set { library.updateSettings { $0.launchOptions.fastBoot = newValue } }
    }

    // MARK: - Library folders

    public var folders: [LibraryFolder] { library.folders }
    public var platforms: [Platform] { Platform.allCases }

    public func setPlatformHint(_ hint: Platform?, for folder: LibraryFolder) {
        library.setPlatformHint(hint, forFolder: folder.id)
    }

    public func removeFolder(_ folder: LibraryFolder) async {
        await library.removeFolder(id: folder.id)
    }

    public func chooseFolders() {
        isChoosingFolders = true
    }

    public func addFolders(_ urls: [URL]) async {
        await library.addFolders(urls)
    }

    // MARK: - PS3

    public var includesRPCS3InstalledGames: Bool {
        get { library.settings.includeRPCS3InstalledGames }
        set { library.updateSettings { $0.includeRPCS3InstalledGames = newValue } }
    }

    public var rpcs3GameFolderPath: String { library.rpcs3GameFolder.path }
}
