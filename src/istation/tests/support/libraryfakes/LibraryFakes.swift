import BusinessLibrary
import DataCatalog
import DataEmulators
import DataStore
import Foundation

// Scripted fakes for `Library`'s services. Tests touch them only from the main actor, which is
// why the mutable ones are `@unchecked Sendable`.

/// An in-memory library file: `load()` returns `state`, `save` replaces it.
public final class MemoryStore: LibraryPersisting, @unchecked Sendable {
    public var state: LibraryState
    public private(set) var saveCount = 0
    public var failsToSave = false

    public init(_ state: LibraryState = LibraryState()) {
        self.state = state
    }

    public func load() -> LibraryState { state }

    public func save(_ state: LibraryState) throws {
        struct DiskFull: LocalizedError { var errorDescription: String? { "The disk is full." } }
        if failsToSave { throw DiskFull() }
        self.state = state
        saveCount += 1
    }
}

/// Returns `games` for every scan and records what it was asked.
public final class ScriptedScanner: LibraryScanning, @unchecked Sendable {
    public var games: [Game]
    public private(set) var scans: [(folders: [LibraryFolder], rpcs3GameFolder: URL?)] = []

    public init(games: [Game] = []) {
        self.games = games
    }

    public func scan(folders: [LibraryFolder], rpcs3GameFolder: URL?) async -> [Game] {
        scans.append((folders, rpcs3GameFolder))
        return games
    }
}

/// Records each start and holds its exit callback until the test calls `finish`.
public final class ScriptedStarter: GameStarting, @unchecked Sendable {
    public private(set) var started: [Game] = []
    public var failure: (any Error)?
    private var exits: [@Sendable (TimeInterval) -> Void] = []

    public init() {}

    public func start(_ game: Game, settings: AppSettings, onExit: @escaping @Sendable (TimeInterval) -> Void) throws {
        if let failure { throw failure }
        started.append(game)
        exits.append(onExit)
    }

    /// Ends the most recent session after `duration` seconds of play.
    public func finish(after duration: TimeInterval) {
        exits.removeLast()(duration)
    }
}

/// Answers from a fixed table of installed apps.
public struct FixedDetector: EmulatorDetecting {
    public var apps: [EmulatorKind: URL]

    public init(_ apps: [EmulatorKind: URL] = [:]) {
        self.apps = apps
    }

    public func installedApp(for kind: EmulatorKind) -> URL? { apps[kind] }
}

/// Real-shaped games, as LibraryScanner reports them for the disc fixtures.
public enum FixtureGames {
    public static let crash = Game(
        title: "Crash Bandicoot", serial: "SCUS-94900", platform: .ps1,
        location: URL(fileURLWithPath: "/Games/PS1/Crash Bandicoot (USA).cue"),
        bootTarget: .path(URL(fileURLWithPath: "/Games/PS1/Crash Bandicoot (USA).cue"))
    )
    public static let ps2 = Game(
        title: "game", serial: "SLES-52338", platform: .ps2,
        location: URL(fileURLWithPath: "/Games/PS2/game.iso"),
        bootTarget: .path(URL(fileURLWithPath: "/Games/PS2/game.iso"))
    )
    public static let demonsSouls = Game(
        title: "Demon's Souls", serial: "BLUS30443", platform: .ps3,
        location: URL(fileURLWithPath: "/Games/PS3/BLUS30443"),
        bootTarget: .path(URL(fileURLWithPath: "/Games/PS3/BLUS30443"))
    )
    public static let all = [crash, ps2, demonsSouls]
}

/// One set of fakes and the `Library` built over them.
@MainActor
public struct LibraryHarness {
    public let store: MemoryStore
    public let scanner: ScriptedScanner
    public let starter: ScriptedStarter
    public let library: Library

    public static let defaultRPCS3GameFolder = URL(fileURLWithPath: "/Sandbox/rpcs3/dev_hdd0/game")

    public init(
        _ state: LibraryState = LibraryState(),
        scanned: [Game] = [],
        installed: [EmulatorKind: URL] = [:],
        now: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 1_793_000_000) }
    ) {
        store = MemoryStore(state)
        scanner = ScriptedScanner(games: scanned)
        starter = ScriptedStarter()
        library = Library(
            store: store,
            scanner: scanner,
            launcher: starter,
            detector: FixedDetector(installed),
            defaultRPCS3GameFolder: Self.defaultRPCS3GameFolder,
            now: now
        )
    }

    /// Lets the main actor run the work `Library` queued (a session ending) until `condition` holds.
    public func settle(until condition: () -> Bool) async {
        for _ in 0..<100 where !condition() {
            await Task.yield()
        }
    }
}
