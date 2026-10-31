import BusinessDiscovery
import BusinessLaunching
import BusinessScanning
import DataCatalog
import DataEmulators
import DataStore
import Foundation

// The services `Library` runs on, as protocols so tests and previews inject fakes. The live
// implementations are the conformances below; only PresentationApp constructs them.

/// Loads and saves the library's state.
public protocol LibraryPersisting: Sendable {
    func load() -> LibraryState
    func save(_ state: LibraryState) throws
}

/// Finds the games in the library's folders.
public protocol LibraryScanning: Sendable {
    /// `rpcs3GameFolder` is RPCS3's dev_hdd0/game folder, or nil to skip installed PS3 titles.
    func scan(folders: [LibraryFolder], rpcs3GameFolder: URL?) async -> [Game]
}

/// Finds an installed emulator app.
public protocol EmulatorDetecting: Sendable {
    func installedApp(for kind: EmulatorKind) -> URL?
}

/// Starts a game's emulator.
public protocol GameStarting: Sendable {
    /// Returns once the emulator is running; `onExit` gets the session's length when it quits.
    func start(_ game: Game, settings: AppSettings, onExit: @escaping @Sendable (TimeInterval) -> Void) throws
}

extension LibraryStore: LibraryPersisting {}

extension LibraryScanner: LibraryScanning {
    public func scan(folders: [LibraryFolder], rpcs3GameFolder: URL?) async -> [Game] {
        let scanner = self
        return await Task.detached(priority: .userInitiated) {
            var found = scanner.scan(folders: folders)
            if let rpcs3GameFolder {
                found += scanner.scanRPCS3Installed(gameFolder: rpcs3GameFolder)
            }
            return found
        }.value
    }
}

extension EmulatorDiscovery: EmulatorDetecting {}

extension GameLauncher: GameStarting {
    public func start(_ game: Game, settings: AppSettings, onExit: @escaping @Sendable (TimeInterval) -> Void) throws {
        let kind = EmulatorChoice.emulator(for: game.platform)
        try start(game, appBundle: settings.app(for: kind), options: settings.launchOptions, onExit: onExit)
    }
}
