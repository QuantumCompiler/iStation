// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

#if DEBUG
import BusinessPS1
import BusinessSession
import DataLibrary
import Foundation
import os
import PresentationStyles
import SwiftUI

/// A console session for the library's previews: no console. Powering on takes a BIOS's size, refusing
/// another as the console does, and runs nothing; whoever follows the session then hears the snapshots the
/// preview scripts, in order, and the stream stays open after the last, so an opening job stays where the
/// script leaves it. Stop ends every stream with the stopped snapshot, as the session's does.
actor PreviewLibrarySession: ConsoleSessionPowerControls {
    private var current = ConsoleSessionSnapshot()
    /// The snapshots still to send once powered on.
    private var script: [ConsoleSessionSnapshot]
    private var streams: [AsyncStream<ConsoleSessionSnapshot>.Continuation] = []

    /// A session, powered off, that sends `frames` once it is powered on and followed.
    init(frames: [ConsoleSessionSnapshot] = []) {
        script = frames
    }

    var snapshot: ConsoleSessionSnapshot { current }

    func powerOn(bios: [UInt8], exe: PSEXE?) throws(PS1Error) {
        guard bios.count == PS1Bus.biosSize else { throw .biosSize(bios.count) }
        current = ConsoleSessionSnapshot(state: .running, bootIsPending: exe != nil)
        publish()
    }

    func pause() {}

    func resume() {}

    func reset() {}

    func stop() {
        current.state = .stopped
        current.framesPerSecond = 0
        publish()
        for stream in streams { stream.finish() }
        streams = []
    }

    func snapshots() -> AsyncStream<ConsoleSessionSnapshot> {
        let (stream, continuation) = AsyncStream.makeStream(of: ConsoleSessionSnapshot.self)
        continuation.yield(current)
        guard current.state != .stopped else {
            continuation.finish()
            return stream
        }
        if current.state == .running {
            for next in script {
                current = next
                continuation.yield(next)
            }
            script = []
        }
        // Held open after the script's last snapshot, until a stop.
        streams.append(continuation)
        return stream
    }

    private func publish() {
        for stream in streams { stream.yield(current) }
    }
}

/// The library and the person's files for the previews, held in memory as each preview scripts it: the
/// design's made-up games and folders (`html/main.html`'s GAMES and SCAN_FILES), never a real game, a real
/// BIOS or the person's own. A bookmark is its file's path; a file the preview takes away no longer
/// resolves; a file it doesn't make up can't be opened; and the record of the file it holds waits, so a scan stays
/// where the preview leaves it, until `letGo()` — suspended, holding no thread, for as long as the
/// preview lasts. Nothing is read from or written to a disk.
struct PreviewLibraryStorage: LibraryStorage {
    /// The library kept, in memory.
    private let kept: OSAllocatedUnfairLock<Library>
    /// The files there are, by path, with their sizes.
    private let files: [String: Int]
    /// The files taken away, by path: their bookmarks no longer resolve.
    private let missing: Set<String>
    /// The name of the file whose record waits until `letGo()`; nil for none.
    private let held: String?
    /// What the held record waits on.
    private let gate = PreviewGate()

    /// A library keeping `library`, the design's files there unless `missing` takes them away, and the
    /// record of `held` waiting.
    init(library: Library, missing: Set<String> = [], held: String? = nil) {
        kept = OSAllocatedUnfairLock(initialState: library)
        var files: [String: Int] = [:]
        for file in PreviewLibrary.files { files[file.url.path] = file.size }
        files[PreviewLibrary.biosFile.path] = PS1Bus.biosSize
        self.files = files
        self.missing = missing
        self.held = held
    }

    /// Lets the held record go on.
    func letGo() {
        gate.open()
    }

    func library() -> Library { kept.withLock { $0 } }

    func addGames(_ games: [GameRecord]) -> LibraryStore.Added {
        kept.withLock { library in
            let added = library.add(games)
            return LibraryStore.Added(library: library, added: added)
        }
    }

    func renameGame(_ id: GameRecord.ID, to name: String?) throws -> Library {
        try kept.withLock { library in
            try library.rename(id, to: name)
            return library
        }
    }

    func removeGames(_ ids: Set<GameRecord.ID>) -> Library {
        kept.withLock { library in
            library.remove(ids)
            return library
        }
    }

    func markPlayed(_ id: GameRecord.ID, at date: Date) throws -> Library {
        try kept.withLock { library in
            try library.markPlayed(id, at: date)
            return library
        }
    }

    func relocateGame(_ id: GameRecord.ID, to file: GameRecord) throws -> Library {
        try kept.withLock { library in
            try library.relocate(id, to: file)
            return library
        }
    }

    func relocateGames(_ moves: [GameRecord.ID: GameRecord]) -> Library {
        kept.withLock { library in
            library.relocate(moves)
            return library
        }
    }

    func keepBIOS(_ record: BIOSRecord) -> Library {
        kept.withLock { library in
            library.bios = record
            return library
        }
    }

    func bookmark(for url: URL) -> Data { Data(url.path.utf8) }

    /// The design's scanned folder, ~/Games, holds its nine files; any other folder holds none.
    func games(in folder: URL) -> [URL] {
        guard folder.path == PreviewLibrary.gamesFolder.path else { return [] }
        return PreviewLibrary.scanned.map(\.url)
    }

    func record(for url: URL, added: Date) async throws -> GameRecord {
        if url.lastPathComponent == held { await gate.pass() }
        guard let file = PreviewLibrary.file(at: url) else {
            throw KeptFileError.cannotRead(path: url.path, reason: "You don’t have permission to view it.")
        }
        return file.record(added: added)
    }

    func startAccessing(_ url: URL) -> Bool { false }

    func stopAccessing(_ url: URL) {}

    func resolve(_ bookmark: Data) throws -> KeptFile.Resolved {
        let path = String(decoding: bookmark, as: UTF8.self)
        guard files[path] != nil, !missing.contains(path) else {
            // The reason macOS gives for a deleted file's bookmark, as the design's missing dialog records it.
            throw KeptFileError.cannotResolve(reason: "The file doesn’t exist.")
        }
        return KeptFile.Resolved(url: URL(fileURLWithPath: path), isStale: false)
    }

    func size(of url: URL) throws -> Int {
        guard let size = files[url.path] else {
            throw KeptFileError.cannotRead(path: url.path, reason: "The file doesn’t exist.")
        }
        return size
    }

    /// The bytes of the two files a preview reads whole: the BIOS, every byte zero, and the PS-EXE built
    /// in code. Any other file is too big for a preview to make up.
    func bytes(of url: URL) throws -> [UInt8] {
        if url.path == PreviewLibrary.biosFile.path { return [UInt8](repeating: 0, count: PS1Bus.biosSize) }
        if url.path == PreviewLibrary.program.url.path { return PreviewLibrary.programBytes }
        if url.path == PreviewLibrary.notAProgram.url.path { return [UInt8](repeating: 0, count: PreviewLibrary.notAProgram.size) }
        throw KeptFileError.cannotRead(path: url.path, reason: "A preview reads no disc image.")
    }
}

/// A gate a preview's held record waits at, suspended rather than holding a thread, until it opens or the
/// task waiting is cancelled — its scan stopped, or the preview gone; one opened before anything reaches
/// it lets the first through at once.
final class PreviewGate: Sendable {
    private let state = OSAllocatedUnfairLock<(isOpen: Bool, waiting: [UUID: CheckedContinuation<Void, Never>])>(
        initialState: (false, [:])
    )

    /// Waits until the gate opens, or the task is cancelled; at once if either has happened.
    func pass() async {
        let id = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let goesOn = state.withLock { gate in
                    if gate.isOpen || Task.isCancelled { return true }
                    gate.waiting[id] = continuation
                    return false
                }
                if goesOn { continuation.resume() }
            }
        } onCancel: {
            state.withLock { $0.waiting.removeValue(forKey: id) }?.resume()
        }
    }

    /// Opens the gate, letting everything waiting at it through.
    func open() {
        let waiting = state.withLock { gate in
            gate.isOpen = true
            defer { gate.waiting = [:] }
            return Array(gate.waiting.values)
        }
        for continuation in waiting { continuation.resume() }
    }
}

/// The library for the previews, one per visible state, as the design's boards draw them at the Today level
/// (`Mac-LibraryEmpty`, `Mac-TodayLibrary`, `Mac-LibraryGrid`, `Mac-LibraryInspector`,
/// `Mac-LibrarySearchEmpty`, `Mac-LibraryMissing`, `Mac-RemoveConfirm`, `Mac-Rename`, `Mac-LibraryMin`,
/// `Mac-LibraryLight`, `Mac-LibraryContrast`, the scan's and the opening's): the design's made-up games in
/// ~/Games, seen on Nov 22, 2026. Each state is reached as a person reaches it — through the view-model's
/// initializer and intents, a selection, a search and a view among them, never by assigning its state —
/// over a `PreviewLibraryStorage` and a `PreviewLibrarySession` scripted for that state.
@MainActor
enum PreviewLibrary {
    /// One made-up file: where it is, how big, and a .cue's tracks or an .m3u's discs.
    struct File: Sendable {
        /// Its path under ~/Games: "PS1/Harbor Lights (USA).cue".
        var relativePath: String
        /// Its size in bytes, tracks or discs included.
        var size: Int
        /// A .cue's tracks.
        var tracks: [String] = []
        /// An .m3u's discs.
        var discs: [String] = []

        /// Its URL.
        var url: URL { PreviewLibrary.gamesFolder.appendingPathComponent(relativePath) }

        /// Its record, added at `added` and played at `played`, as `GameFiles.record(for:added:)` makes one.
        func record(added: Date, played: Date? = nil) -> GameRecord {
            GameRecord(
                fileName: url.lastPathComponent, folder: url.deletingLastPathComponent().path,
                format: GameFormat(fileName: url.lastPathComponent) ?? .unknown(url.pathExtension), size: size,
                added: added, lastPlayed: played, bookmark: Data(url.path.utf8), tracks: tracks, discs: discs
            )
        }
    }

    /// A made-up home folder, so folders inside it are written from "~".
    nonisolated static let home = "/Users/you"
    /// The design's folder of games, ~/Games.
    nonisolated static let gamesFolder = URL(fileURLWithPath: "/Users/you/Games", isDirectory: true)
    /// The design's kept BIOS, in ~/Documents/Console.
    nonisolated static let biosFile = URL(fileURLWithPath: "/Users/you/Documents/Console/my-console-bios.bin")

    /// Dates in UTC, so every preview reads the same wherever it is drawn.
    nonisolated static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
        return calendar
    }()

    /// `month` `day`, 2026, at `hour`:`minute` UTC.
    nonisolated static func date(_ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    /// Nov 22, 2026, noon: the previews' today.
    nonisolated static let now = date(11, 22)

    // MARK: The design's files

    nonisolated static let harborLights = File(
        relativePath: "PS1/Harbor Lights (USA).cue", size: 512_340_096,
        tracks: ["Harbor Lights (USA) (Track 1).bin", "Harbor Lights (USA) (Track 2).bin"]
    )
    nonisolated static let moonbaseCourier = File(relativePath: "PS1/Moonbase Courier.iso", size: 487_915_520)
    nonisolated static let tidepool = File(
        relativePath: "PS1/Tidepool/Tidepool.m3u", size: 1_953_021_952,
        discs: ["Tidepool (Disc 1).cue", "Tidepool (Disc 2).cue", "Tidepool (Disc 3).cue"]
    )
    nonisolated static let glassOrchard = File(
        relativePath: "PS1/Glass Orchard (Europe).cue", size: 398_458_880, tracks: ["Glass Orchard (Europe).bin"]
    )
    /// The design's homebrew PS-EXE: a 2 KB header and 32 KB of code, built in code.
    nonisolated static let program = File(relativePath: "Homebrew/gpu-test.exe", size: 34_816)
    nonisolated static let nightFerry = File(relativePath: "PS2/Night Ferry.iso", size: 3_912_040_448)
    nonisolated static let lanternStreet = File(
        relativePath: "PS1/Lantern Street.cue", size: 402_653_184, tracks: ["Lantern Street.bin"]
    )
    /// A file named like a program that isn't one: 4 KB of zeros.
    nonisolated static let notAProgram = File(relativePath: "Homebrew/blank.exe", size: 4_096)

    /// The PS-EXE's bytes: a program that loads 32 KB of zeros at 0x80010000 and starts there.
    nonisolated static let programBytes = PSEXE(
        pc: 0x8001_0000, destination: 0x8001_0000, text: [UInt8](repeating: 0, count: 32_768)
    ).bytes

    /// The design's scanned folder, ~/Games, in the order the search finds its files: the library's two
    /// games, the four it adds, and three backups.
    nonisolated static let scanned: [File] = [
        harborLights, moonbaseCourier, tidepool, glassOrchard, program, nightFerry,
        File(relativePath: "Backups/Photos 2019.iso", size: 734_003_200),
        File(relativePath: "Backups/half-copy.cue", size: 211_812_352, tracks: ["half-copy.bin"]),
        File(relativePath: "Backups/locked.iso", size: 681_574_400),
    ]

    /// Every made-up file there is.
    nonisolated static let files: [File] = scanned + [lanternStreet, notAProgram]

    /// The made-up file at `url`; nil for none.
    nonisolated static func file(at url: URL) -> File? {
        files.first { $0.url.path == url.path }
    }

    /// The design's kept BIOS, checked Nov 20.
    nonisolated static let bios = BIOSRecord(
        fileName: biosFile.lastPathComponent, folder: biosFile.deletingLastPathComponent().path,
        size: PS1Bus.biosSize, sha1: "3f9a1c0e52d488b0e7a14c269d0f51aa7b21c3e8", checked: date(11, 20),
        bookmark: Data(biosFile.path.utf8)
    )

    /// The design's seven games, as the library keeps them: their dates added and last played.
    static func games() -> [GameRecord] {
        [
            harborLights.record(added: date(11, 14), played: date(11, 22, 9, 41)),
            moonbaseCourier.record(added: date(11, 14), played: date(11, 21, 21, 10)),
            tidepool.record(added: date(11, 12), played: date(11, 12)),
            glassOrchard.record(added: date(11, 14)),
            program.record(added: date(11, 18), played: date(11, 18)),
            nightFerry.record(added: date(11, 14)),
            lanternStreet.record(added: date(10, 2), played: date(10, 30)),
        ]
    }

    // MARK: The library

    /// The library over `storage`, its opening job powering on `session`.
    static func library(
        over storage: PreviewLibraryStorage, session: PreviewLibrarySession = PreviewLibrarySession()
    ) -> LibraryViewModel {
        LibraryViewModel(
            storage: storage, session: session, home: home, calendar: calendar, now: { now }, onRun: { _ in }
        )
    }

    /// The library keeping the design's games, Lantern Street's file taken away, its opening job powering on
    /// `session`.
    static func library(session: PreviewLibrarySession = PreviewLibrarySession()) -> LibraryViewModel {
        library(over: designStorage(), session: session)
    }

    /// The design's games and BIOS, Lantern Street's file taken away.
    static func designStorage() -> PreviewLibraryStorage {
        PreviewLibraryStorage(library: Library(bios: bios, games: games()), missing: [lanternStreet.url.path])
    }

    /// The kept game whose file is `file`.
    static func game(_ file: File, in library: LibraryViewModel) -> GameRecord.ID? {
        library.games.first { $0.path == file.url.path }?.id
    }

    /// The empty library, once a BIOS is kept (library-empty).
    static func empty() -> LibraryViewModel {
        library(over: PreviewLibraryStorage(library: Library(bios: bios)))
    }

    /// The library before discs can be read, Game info open on its first game (today-library), as the
    /// light and high-contrast boards draw it too.
    static func today() -> LibraryViewModel {
        let library = library()
        library.toggleInfo()
        return library
    }

    /// The library alone, Game info closed: the default window, and the least one (library-min).
    static func listed() -> LibraryViewModel {
        library()
    }

    /// The grid of tiles, Tidepool selected (library-grid).
    static func grid() -> LibraryViewModel {
        let library = library()
        library.showGames(as: .grid)
        library.select(game(tidepool, in: library))
        return library
    }

    /// Game info open on Tidepool (library-inspector).
    static func info() -> LibraryViewModel {
        let library = library()
        library.select(game(tidepool, in: library))
        library.toggleInfo()
        return library
    }

    /// Game info open on the PS-EXE, whose Play is on.
    static func infoForAProgram() -> LibraryViewModel {
        let library = library()
        library.select(game(program, in: library))
        library.toggleInfo()
        return library
    }

    /// A search that finds nothing: "zebra" (library-search-empty).
    static func searchEmpty() -> LibraryViewModel {
        let library = library()
        library.search(for: "zebra")
        return library
    }

    /// Game info open on Lantern Street, whose file is gone (library-missing): flagged once the library has
    /// looked for its games' files, as it does when it opens.
    static func missing() -> LibraryViewModel {
        let library = library()
        library.select(game(lanternStreet, in: library))
        library.toggleInfo()
        return library
    }

    /// Remove from Library… asked of Glass Orchard, Game info open on it (remove-confirm).
    static func removeConfirm() -> LibraryViewModel {
        let library = library()
        library.select(game(glassOrchard, in: library))
        library.toggleInfo()
        library.askToRemove()
        return library
    }

    /// Lantern Street played though its file is gone: the library asks to locate it or remove it.
    static func locateOrRemove() -> LibraryViewModel {
        let library = library()
        library.select(game(lanternStreet, in: library))
        library.toggleInfo()
        let id = library.selection
        Task { [weak library] in
            // The library looks for its games' files on a task of its own: wait until it has flagged the
            // file missing, as a person sees before pressing Locate…, for two seconds at most.
            let deadline = ContinuousClock.now.advanced(by: .seconds(2))
            while let shown = library, shown.info?.action != .locate, ContinuousClock.now < deadline {
                try? await Task.sleep(for: .milliseconds(5))
            }
            library?.play(id)
        }
        return library
    }

    /// The rename sheet open on gpu-test, Game info open on it (rename).
    static func rename() -> LibraryViewModel {
        let library = library()
        library.select(game(program, in: library))
        library.toggleInfo()
        library.rename()
        return library
    }

    // MARK: Add Folder…

    /// The library holding Harbor Lights and Moonbase Courier, as the scan boards begin. Every other file
    /// opens, as the Today scan's do, so each is added: "Added 7 games. 2 already in your library."
    static func beforeScan(held: String? = nil) -> PreviewLibraryStorage {
        PreviewLibraryStorage(library: Library(bios: bios, games: Array(games().prefix(2))), held: held)
    }

    /// Add Folder…'s chooser open over the library (scan-picker).
    static func scanPicker() -> LibraryViewModel {
        let library = library(over: beforeScan())
        library.chooseFolder()
        return library
    }

    /// ~/Games scanned, reading its fifth file, gpu-test.exe (scan-running).
    static func scanRunning() -> LibraryViewModel {
        let library = library(over: beforeScan(held: program.url.lastPathComponent))
        library.chooseFolder()
        library.scan.scan(gamesFolder)
        return library
    }

    /// ~/Games scanned, stopped once five files were read (scan-stopped).
    static func scanStopped() -> LibraryViewModel {
        let storage = beforeScan(held: nightFerry.url.lastPathComponent)
        let library = library(over: storage)
        library.chooseFolder()
        library.scan.scan(gamesFolder)
        Task { [weak library] in
            // The scan reads on a task of its own: watch what it shows, as the sheet does, and press Stop
            // while it reads the sixth file, for two seconds at most.
            let deadline = ContinuousClock.now.advanced(by: .seconds(2))
            while let shown = library, shown.scan.results.count < 5, ContinuousClock.now < deadline {
                try? await Task.sleep(for: .milliseconds(5))
            }
            library?.scan.stop()
            storage.letGo()
        }
        return library
    }

    /// ~/Games scanned to the end (scan-done).
    static func scanDone() -> LibraryViewModel {
        let library = library(over: beforeScan())
        library.chooseFolder()
        library.scan.scan(gamesFolder)
        return library
    }

    // MARK: Play

    /// gpu-test opening: powered on with the BIOS and the program, the BIOS on its way to its shell at
    /// frame 90 (the today flow's opening job).
    static func opening() -> LibraryViewModel {
        let session = PreviewLibrarySession(frames: [
            ConsoleSessionSnapshot(state: .running, frame: 90, framesPerSecond: 60, bootIsPending: true),
        ])
        let library = library(session: session)
        library.select(game(program, in: library))
        library.play()
        return library
    }

    /// A file named like a PS-EXE that isn't one, refused at "Open the file".
    static func openingRefused() -> LibraryViewModel {
        let games = games() + [notAProgram.record(added: date(11, 22))]
        let library = library(over: PreviewLibraryStorage(library: Library(bios: bios, games: games)))
        library.select(game(notAProgram, in: library))
        library.play()
        return library
    }
}

extension View {
    /// The preview as the window shows it: the default window, its toolbar included.
    func inPreviewWindow() -> some View {
        frame(width: Metrics.layout.windowWidth, height: Metrics.layout.windowHeight)
    }

    /// The preview as the least window shows it, its toolbar included (library-min).
    func inLeastWindow() -> some View {
        frame(width: Metrics.layout.windowMinWidth, height: Metrics.layout.windowMinHeight)
    }
}
#endif
