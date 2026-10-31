import BusinessIdentification
import DataCatalog
import DataEmulators
import DataStore
import Foundation
import Observation

/// Which games a view of the library shows.
public enum LibraryFilter: Hashable, Sendable {
    case all
    case recent
    case platform(Platform)
}

/// The library and everything a person does with it: its folders, games, settings, play history
/// and the one running game.
///
/// The one source of truth the Presentation view-models read. Its services are injected as the
/// protocols in Services.swift, so tests and previews run it over fakes.
@MainActor
@Observable
public final class Library {
    public private(set) var games: [Game] = []
    public private(set) var folders: [LibraryFolder] = []
    public private(set) var settings = AppSettings()
    public private(set) var isScanning = false
    /// The game whose emulator is running; only one runs at a time.
    public private(set) var runningGameID: String?
    /// The last failure, in words a person can act on.
    public private(set) var lastError: String?

    private let store: any LibraryPersisting
    private let scanner: any LibraryScanning
    private let launcher: any GameStarting
    private let detector: any EmulatorDetecting
    private let defaultRPCS3GameFolder: URL
    private let now: @Sendable () -> Date

    public init(
        store: any LibraryPersisting,
        scanner: any LibraryScanning,
        launcher: any GameStarting,
        detector: any EmulatorDetecting,
        defaultRPCS3GameFolder: URL,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.scanner = scanner
        self.launcher = launcher
        self.detector = detector
        self.defaultRPCS3GameFolder = defaultRPCS3GameFolder
        self.now = now
        let state = store.load()
        games = state.games
        folders = state.folders
        settings = state.settings
        detectEmulators()
    }

    // MARK: - Queries

    public func games(for filter: LibraryFilter, matching search: String) -> [Game] {
        var result: [Game]
        switch filter {
        case .all:
            result = games
        case .recent:
            result = games.filter { $0.lastPlayed != nil }
                .sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
        case .platform(let platform):
            result = games.filter { $0.platform == platform }
        }
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return result }
        return result.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || ($0.serial?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    public func count(of platform: Platform) -> Int {
        games.reduce(0) { $0 + ($1.platform == platform ? 1 : 0) }
    }

    /// RPCS3's installed-games folder: the one in Settings, else RPCS3's default.
    public var rpcs3GameFolder: URL {
        settings.rpcs3GameFolder ?? defaultRPCS3GameFolder
    }

    // MARK: - Folders

    /// Adds the folders not already in the library, each with the console its name suggests, then rescans.
    public func addFolders(_ urls: [URL]) async {
        for url in urls where !folders.contains(where: { $0.url == url }) {
            folders.append(LibraryFolder(url: url, platformHint: DiscIdentifier.platformHint(fromPath: url)))
        }
        save()
        await rescan()
    }

    public func removeFolder(id: UUID) async {
        folders.removeAll { $0.id == id }
        save()
        await rescan()
    }

    public func setPlatformHint(_ hint: Platform?, forFolder id: UUID) {
        guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[index].platformHint = hint
        save()
    }

    /// Rebuilds the game list from the folders, keeping each game's play history by its ID.
    public func rescan() async {
        guard !isScanning else { return }
        isScanning = true
        let scanned = await scanner.scan(
            folders: folders,
            rpcs3GameFolder: settings.includeRPCS3InstalledGames ? rpcs3GameFolder : nil
        )
        games = PlayHistory.merge(scanned: scanned, previous: games)
        isScanning = false
        save()
    }

    // MARK: - Settings

    public func updateSettings(_ change: (inout AppSettings) -> Void) {
        change(&settings)
        save()
    }

    /// Fills in every emulator that has no app chosen yet with the one installed on this Mac, if any.
    public func detectEmulators() {
        var changed = false
        for kind in EmulatorKind.allCases where settings.app(for: kind) == nil {
            if let found = detector.installedApp(for: kind) {
                settings.setApp(found, for: kind)
                changed = true
            }
        }
        if changed { save() }
    }

    // MARK: - Playing

    public func launch(_ game: Game) {
        guard runningGameID == nil else {
            lastError = "Another game is already running."
            return
        }
        let gameID = game.id
        do {
            try launcher.start(game, settings: settings) { [weak self] duration in
                Task { @MainActor in self?.sessionEnded(gameID: gameID, duration: duration) }
            }
        } catch {
            lastError = error.localizedDescription
            return
        }
        runningGameID = gameID
        if let index = games.firstIndex(where: { $0.id == gameID }) {
            games[index].lastPlayed = now()
        }
        save()
    }

    public func dismissError() {
        lastError = nil
    }

    private func sessionEnded(gameID: String, duration: TimeInterval) {
        runningGameID = nil
        if let index = games.firstIndex(where: { $0.id == gameID }) {
            games[index].playTime += duration
        }
        save()
    }

    // MARK: - Persistence

    private func save() {
        do {
            try store.save(LibraryState(folders: folders, games: games, settings: settings))
        } catch {
            lastError = "Couldn’t save the library: \(error.localizedDescription)"
        }
    }
}
