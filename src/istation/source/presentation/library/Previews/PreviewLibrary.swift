#if DEBUG
import BusinessLibrary
import DataCatalog
import DataEmulators
import DataStore
import Foundation

/// A `Library` for previews: in memory, no disk writes, no processes, no real home folder.
@MainActor
enum PreviewLibrary {
    static func make(_ state: LibraryState, scanForever: Bool = false) -> Library {
        Library(
            store: PreviewStore(state: state),
            scanner: PreviewScanner(games: state.games, scanForever: scanForever),
            launcher: PreviewStarter(),
            detector: PreviewDetector(),
            defaultRPCS3GameFolder: URL(fileURLWithPath: "/Preview/Library/Application Support/rpcs3/dev_hdd0/game")
        )
    }

    /// The grid over `library`, showing the whole library.
    static func grid(_ library: Library) -> LibraryGridViewModel {
        LibraryGridViewModel(library: library, query: { (.all, "") }, requestFolders: {})
    }

    /// Games as LibraryScanner reports them for the disc fixtures in tests/support/discfixtures
    /// (same titles, serials and boot targets), with play history added. Never data from the
    /// user's own library (ADR 0009).
    static let recorded = LibraryState(
        folders: [LibraryFolder(url: URL(fileURLWithPath: "/Games/PS1"), platformHint: .ps1)],
        games: [
            Game(
                title: "Crash Bandicoot", serial: "SCUS-94900", platform: .ps1,
                location: URL(fileURLWithPath: "/Games/PS1/Crash Bandicoot (USA).cue"),
                bootTarget: .path(URL(fileURLWithPath: "/Games/PS1/Crash Bandicoot (USA).cue")),
                lastPlayed: Date(timeIntervalSince1970: 1_793_000_000), playTime: 11_100
            ),
            Game(
                title: "Demon's Souls", serial: "BLUS30443", platform: .ps3,
                location: URL(fileURLWithPath: "/Games/PS3/BLUS30443"),
                bootTarget: .path(URL(fileURLWithPath: "/Games/PS3/BLUS30443"))
            ),
            Game(
                title: "game", serial: "SLES-52338", platform: .ps2,
                location: URL(fileURLWithPath: "/Games/PS2/game.iso"),
                bootTarget: .path(URL(fileURLWithPath: "/Games/PS2/game.iso")),
                playTime: 45
            ),
        ],
        settings: {
            var settings = AppSettings()
            settings.setApp(URL(fileURLWithPath: "/Applications/PCSX2.app"), for: .pcsx2)
            return settings
        }()
    )
}

struct PreviewStore: LibraryPersisting {
    let state: LibraryState
    func load() -> LibraryState { state }
    func save(_ state: LibraryState) throws {}
}

struct PreviewScanner: LibraryScanning {
    let games: [Game]
    let scanForever: Bool

    func scan(folders: [LibraryFolder], rpcs3GameFolder: URL?) async -> [Game] {
        if scanForever { try? await Task.sleep(for: .seconds(3600)) }
        return games
    }
}

/// Starts nothing; the game stays "running" for the preview's lifetime.
struct PreviewStarter: GameStarting {
    func start(_ game: Game, settings: AppSettings, onExit: @escaping @Sendable (TimeInterval) -> Void) throws {}
}

struct PreviewDetector: EmulatorDetecting {
    func installedApp(for kind: EmulatorKind) -> URL? { nil }
}
#endif
