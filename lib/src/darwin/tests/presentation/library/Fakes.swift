// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import BusinessSession
import DataLibrary
import Foundation
@testable import PresentationLibrary
import SupportSandbox

/// A library and the person's files held in memory, as the tests script them: the library a `Library`
/// value changed by its own in-memory calls; made-up files by path, whose bookmark is the path; files a
/// test moves (their bookmarks then stale) or takes away; failures a test plants; and every call in the
/// order made. A file under `disk`, a `Sandbox`'s folder, is a real one: the search, its records and its
/// bookmarks are `GameFiles`' and `KeptFile`'s own, so a scan runs over a folder the test built. A test
/// can hold the search, each record, each resolve or a file's whole read where it is, so a Stop or a
/// Cancel can land mid-way; a held call lets go after two seconds at most, so a test that forgets can't hang.
/// A held record waits suspended, holding no thread, as the previews' does; the synchronous calls, which
/// the view-models make in detached tasks, wait on theirs.
// @unchecked: every stored `var` is read and written only under `lock`, and the `let`s are Sendable.
final class MemoryStorage: LibraryStorage, @unchecked Sendable {
    /// One call the view-models made.
    enum Call: Equatable, Sendable {
        case library, addGames([String]), renameGame(String?), removeGames, markPlayed, relocateGame(String), keepBIOS
        case relocateGames([String])
        case bookmark(String), games(String), record(String), startAccessing(String), stopAccessing(String)
        case resolve, size(String), bytes(String)
    }

    /// The calls a test makes fail, and with what.
    struct Failures {
        var load: LibraryStoreError?
        var write: LibraryStoreError?
        var bookmark: KeptFileError?
        var resolve: KeptFileError?
        var size: KeptFileError?
        var bytes: KeptFileError?
        var find: KeptFileError?
        /// Records that fail, by the file's name.
        var record: [String: KeptFileError] = [:]
        /// Sizes and whole-file reads that fail, by the file's name.
        var sizeOf: [String: KeptFileError] = [:]
        var bytesOf: [String: KeptFileError] = [:]
    }

    private let lock = NSLock()
    private var kept: Library
    private var files: [String: [UInt8]] = [:]
    private var moves: [String: URL] = [:]
    private var log: [Call] = []
    private var planted = Failures()
    private var access = 0
    private var holdsSearch = false
    private var holdsRecords = false
    private var holdsResolves = false
    private var heldReads: Set<String> = []
    private var waiting = 0
    private let gate = HeldCalls()
    /// The folder whose files are real: a `Sandbox`'s.
    let disk: URL?

    /// A library keeping `library`, holding `files`, with the files under `disk` real.
    init(library: Library = Library(), files: [URL: [UInt8]] = [:], disk: URL? = nil) {
        kept = library
        self.disk = disk
        for (url, bytes) in files { self.files[url.path] = bytes }
    }

    // MARK: What a test sets and reads

    /// The library as it is kept now.
    var saved: Library { lock.withLock { kept } }
    /// Every call, in order.
    var calls: [Call] { lock.withLock { log } }
    /// The folders' security-scoped access started and not yet stopped.
    var openAccess: Int { lock.withLock { access } }
    /// How many calls wait at the gate.
    var waitingCalls: Int { lock.withLock { waiting } }
    /// How many times the file at `url` was read whole.
    func reads(of url: URL) -> Int { calls.count { $0 == .bytes(url.path) } }

    /// Puts `bytes` at `url`.
    func put(_ bytes: [UInt8], at url: URL) { lock.withLock { files[url.path] = bytes } }

    /// Takes the file at `url` away: its bookmark no longer resolves.
    func delete(_ url: URL) { lock.withLock { _ = files.removeValue(forKey: url.path) } }

    /// Moves the file at `from` to `to`: a bookmark to `from` then leads to `to`, stale.
    func move(_ from: URL, to: URL) {
        lock.withLock {
            files[to.path] = files.removeValue(forKey: from.path)
            moves[from.path] = to
        }
    }

    /// Makes the calls `failures` names fail.
    func fail(_ failures: Failures) { lock.withLock { planted = failures } }

    /// Holds the search from now until `letGo()`, or until it is cancelled.
    func holdSearch() { lock.withLock { holdsSearch = true } }

    /// Holds each record from now, one `letGo()` letting one go on.
    func holdRecords() { lock.withLock { holdsRecords = true } }

    /// Holds each resolve from now — a look for the games' files, a program's or the BIOS's — one
    /// `letGo()` letting one go on.
    func holdResolves() { lock.withLock { holdsResolves = true } }

    /// Holds each whole read of the file named `name` from now, one `letGo()` letting one go on.
    func holdReads(of name: String) { lock.withLock { _ = heldReads.insert(name) } }

    /// Lets the held search go on, and one held record.
    func letGo() {
        lock.withLock { holdsSearch = false }
        gate.signal()
    }

    /// Holds no more records, and lets every waiting one go.
    func letAllGo() {
        let count = lock.withLock {
            holdsRecords = false
            holdsSearch = false
            holdsResolves = false
            heldReads = []
            return waiting
        }
        for _ in 0..<max(count, 1) { gate.signal() }
    }

    // MARK: LibraryStorage

    func library() throws -> Library {
        try lock.withLock {
            log.append(.library)
            if let failure = planted.load { throw failure }
            return kept
        }
    }

    func addGames(_ games: [GameRecord]) throws -> LibraryStore.Added {
        try lock.withLock {
            log.append(.addGames(games.map(\.fileName)))
            if let failure = planted.write { throw failure }
            let added = kept.add(games)
            return LibraryStore.Added(library: kept, added: added)
        }
    }

    func renameGame(_ id: GameRecord.ID, to name: String?) throws -> Library {
        try lock.withLock {
            log.append(.renameGame(name))
            if let failure = planted.write { throw failure }
            try kept.rename(id, to: name)
            return kept
        }
    }

    func removeGames(_ ids: Set<GameRecord.ID>) throws -> Library {
        try lock.withLock {
            log.append(.removeGames)
            if let failure = planted.write { throw failure }
            kept.remove(ids)
            return kept
        }
    }

    func markPlayed(_ id: GameRecord.ID, at date: Date) throws -> Library {
        try lock.withLock {
            log.append(.markPlayed)
            if let failure = planted.write { throw failure }
            try kept.markPlayed(id, at: date)
            return kept
        }
    }

    func relocateGame(_ id: GameRecord.ID, to file: GameRecord) throws -> Library {
        try lock.withLock {
            log.append(.relocateGame(file.fileName))
            if let failure = planted.write { throw failure }
            try kept.relocate(id, to: file)
            return kept
        }
    }

    func relocateGames(_ moves: [GameRecord.ID: GameRecord]) throws -> Library {
        try lock.withLock {
            log.append(.relocateGames(kept.games.compactMap { moves[$0.id]?.fileName }))
            if let failure = planted.write { throw failure }
            kept.relocate(moves)
            return kept
        }
    }

    func keepBIOS(_ record: BIOSRecord) throws -> Library {
        try lock.withLock {
            log.append(.keepBIOS)
            if let failure = planted.write { throw failure }
            kept.bios = record
            return kept
        }
    }

    func bookmark(for url: URL) throws -> Data {
        try lock.withLock {
            log.append(.bookmark(url.path))
            if let failure = planted.bookmark { throw failure }
            if isReal(url) { return try KeptFile.bookmark(for: url) }
            guard files[url.path] != nil else { throw KeptFileError.cannotBookmark(path: url.path, reason: "No such file.") }
            return Data(url.path.utf8)
        }
    }

    func games(in folder: URL) throws -> [URL] {
        let failure = lock.withLock {
            log.append(.games(folder.lastPathComponent))
            return planted.find
        }
        if let failure { throw failure }
        let deadline = Date().addingTimeInterval(2)
        while lock.withLock({ holdsSearch }), !Task.isCancelled, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.001)
        }
        if isReal(folder) { return try GameFiles.find(in: folder) }
        let base = folder.path + "/"
        return lock.withLock { files.keys.filter { $0.hasPrefix(base) && GameFormat(fileName: $0) != nil } }
            .sorted()
            .map { URL(fileURLWithPath: $0) }
    }

    func record(for url: URL, added: Date) async throws -> GameRecord {
        let (failure, held) = lock.withLock {
            log.append(.record(url.lastPathComponent))
            return (planted.record[url.lastPathComponent], holdsRecords)
        }
        if held { await pass() }
        if let failure { throw failure }
        if isReal(url) { return try GameFiles.record(for: url, added: added) }
        let size = try lock.withLock {
            guard let bytes = files[url.path] else { throw KeptFileError.cannotRead(path: url.path, reason: "No such file.") }
            return bytes.count
        }
        return GameRecord(
            fileName: url.lastPathComponent, folder: url.deletingLastPathComponent().path,
            format: GameFormat(fileName: url.lastPathComponent) ?? .unknown(url.pathExtension.lowercased()), size: size,
            added: Date(timeIntervalSinceReferenceDate: added.timeIntervalSinceReferenceDate.rounded(.down)),
            bookmark: Data(url.path.utf8)
        )
    }

    func startAccessing(_ url: URL) -> Bool {
        lock.withLock {
            log.append(.startAccessing(url.lastPathComponent))
            access += 1
            return true
        }
    }

    func stopAccessing(_ url: URL) {
        lock.withLock {
            log.append(.stopAccessing(url.lastPathComponent))
            access -= 1
        }
    }

    func resolve(_ bookmark: Data) throws -> KeptFile.Resolved {
        if lock.withLock({ holdsResolves }) { wait() }
        return try lock.withLock {
            log.append(.resolve)
            if let failure = planted.resolve { throw failure }
            let path = String(decoding: bookmark, as: UTF8.self)
            if let moved = moves[path] { return KeptFile.Resolved(url: moved, isStale: true) }
            if files[path] != nil { return KeptFile.Resolved(url: URL(fileURLWithPath: path), isStale: false) }
            if disk != nil, !bookmark.isEmpty, path.first != "/" { return try KeptFile.resolve(bookmark) }
            throw KeptFileError.cannotResolve(reason: "No such file.")
        }
    }

    func size(of url: URL) throws -> Int {
        try lock.withLock {
            log.append(.size(url.path))
            if let failure = planted.size ?? planted.sizeOf[url.lastPathComponent] { throw failure }
            if let bytes = files[url.path] { return bytes.count }
            if isReal(url) { return try KeptFile.size(at: url) }
            throw KeptFileError.cannotRead(path: url.path, reason: "No such file.")
        }
    }

    func bytes(of url: URL) throws -> [UInt8] {
        if lock.withLock({ heldReads.contains(url.lastPathComponent) }) { wait() }
        return try lock.withLock {
            log.append(.bytes(url.path))
            if let failure = planted.bytes ?? planted.bytesOf[url.lastPathComponent] { throw failure }
            if let bytes = files[url.path] { return bytes }
            if isReal(url) { return try KeptFile.bytes(at: url) }
            throw KeptFileError.cannotRead(path: url.path, reason: "No such file.")
        }
    }

    /// Waits at the gate on this thread until a `letGo()`, for two seconds at most.
    private func wait() {
        lock.withLock { waiting += 1 }
        gate.wait()
        lock.withLock { waiting -= 1 }
    }

    /// Waits at the gate, suspended, until a `letGo()`, for two seconds at most.
    private func pass() async {
        lock.withLock { waiting += 1 }
        await gate.pass()
        lock.withLock { waiting -= 1 }
    }

    /// Whether `url` is a real file, under the test's `Sandbox` folder.
    private func isReal(_ url: URL) -> Bool {
        guard let disk else { return false }
        return (GameRecord.standardizedPath(of: url) + "/").hasPrefix(GameRecord.standardizedPath(of: disk) + "/")
    }
}

/// The gate `MemoryStorage`'s held calls wait at, each for two seconds at most: a synchronous one on its
/// thread, an asynchronous one suspended, holding none. Each `signal()` lets the call that has waited
/// longest go on, or, with none waiting, the next to come.
// @unchecked: `permits` and `waiting` are read and written only under `lock`.
final class HeldCalls: @unchecked Sendable {
    private let lock = NSLock()
    private var permits = 0
    private var waiting: [(id: UUID, goOn: @Sendable () -> Void)] = []

    /// Lets one call go on.
    func signal() {
        let next = lock.withLock { () -> (@Sendable () -> Void)? in
            guard !waiting.isEmpty else {
                permits += 1
                return nil
            }
            return waiting.removeFirst().goOn
        }
        next?()
    }

    /// Waits on this thread for a `signal()`, two seconds at most.
    func wait() {
        let semaphore = DispatchSemaphore(value: 0)
        guard let id = enqueue({ semaphore.signal() }) else { return }
        if semaphore.wait(timeout: .now() + 2) == .timedOut, !dequeue(id) {
            // Let go as the wait gave up: the signal is on its way.
            semaphore.wait()
        }
    }

    /// Waits suspended for a `signal()`, two seconds at most.
    func pass() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            guard let id = enqueue({ continuation.resume() }) else { return continuation.resume() }
            Task.detached {
                try? await Task.sleep(for: .seconds(2))
                if self.dequeue(id) { continuation.resume() }
            }
        }
    }

    /// Takes a permit, nil; or queues `goOn` and returns its place.
    private func enqueue(_ goOn: @escaping @Sendable () -> Void) -> UUID? {
        lock.withLock {
            if permits > 0 {
                permits -= 1
                return nil
            }
            let id = UUID()
            waiting.append((id, goOn))
            return id
        }
    }

    /// Takes the call at `id` out of the queue: true when it was still waiting.
    private func dequeue(_ id: UUID) -> Bool {
        lock.withLock {
            guard let index = waiting.firstIndex(where: { $0.id == id }) else { return false }
            waiting.remove(at: index)
            return true
        }
    }
}

extension MemoryStorage: CustomReflectable {
    /// A short account of the storage for a failed expectation: the files' bytes, a BIOS's 512 KB among
    /// them, would take seconds to print and hold up every other test waiting on the main actor.
    var customMirror: Mirror {
        Mirror(self, children: ["games": saved.games.map(\.fileName), "calls": calls.count])
    }
}

/// A console session the tests drive: powering on takes a BIOS's size and refuses another as the
/// console does, notes the PS-EXE it was given — pending until a frame reaches the shell — and runs
/// nothing until a test sends the frames it wants seen; stop finishes every stream with the stopped
/// snapshot. It records every call, and notes each power-on in `log` when given one, so a test can see
/// what came before what. A test can hold power-ons where they are, after the call is recorded and
/// before it takes effect, so a Cancel can land while one is under way; and hold stops before they are
/// recorded and take effect, so a job opened meanwhile can be seen to wait for one.
actor FakePowerSession: ConsoleSessionPowerControls, CustomReflectable {
    /// One call made of the session.
    enum Call: Equatable, Sendable {
        case powerOn(bytes: Int, exe: Bool), pause, resume, reset, stop, snapshots
    }

    private(set) var calls: [Call] = []
    private(set) var current = ConsoleSessionSnapshot()
    /// The bytes and the program the session was last powered on with.
    private(set) var bios: [UInt8] = []
    private(set) var exe: PSEXE?
    private var streams: [AsyncStream<ConsoleSessionSnapshot>.Continuation] = []
    private let log: EventLog?
    private var holdsPowerOns = false
    private var held: [CheckedContinuation<Void, Never>] = []
    private var holdsStops = false
    private var heldStops: [CheckedContinuation<Void, Never>] = []

    /// A session, powered off, noting its power-ons in `log`.
    init(log: EventLog? = nil) {
        self.log = log
    }

    /// The calls, without the snapshot streams.
    var controls: [Call] { calls.filter { $0 != .snapshots } }

    /// How many power-ons wait to be let go.
    var heldCount: Int { held.count }

    /// How many stops wait to be let go.
    var heldStopCount: Int { heldStops.count }

    /// Whether a job follows the session's snapshots now.
    var isFollowed: Bool { !streams.isEmpty }

    /// Holds every power-on from now, once it has taken a BIOS's size, until `letGo()`.
    func holdPowerOns() { holdsPowerOns = true }

    /// Lets every held power-on go on, and holds no more.
    func letGo() {
        holdsPowerOns = false
        let waiting = held
        held = []
        for continuation in waiting { continuation.resume() }
    }

    /// Holds every stop from now, before it is recorded or takes effect, until `letStopsGo()`.
    func holdStops() { holdsStops = true }

    /// Lets every held stop go on, and holds no more.
    func letStopsGo() {
        holdsStops = false
        let waiting = heldStops
        heldStops = []
        for continuation in waiting { continuation.resume() }
    }

    var snapshot: ConsoleSessionSnapshot { current }

    func powerOn(bios: [UInt8], exe: PSEXE?) async throws(PS1Error) {
        calls.append(.powerOn(bytes: bios.count, exe: exe != nil))
        guard bios.count == PS1Bus.biosSize else { throw .biosSize(bios.count) }
        if holdsPowerOns { await withCheckedContinuation { held.append($0) } }
        self.bios = bios
        self.exe = exe
        log?.note("powered on")
        current = ConsoleSessionSnapshot(state: .running, bootIsPending: exe != nil)
        publish()
    }

    func pause() { calls.append(.pause) }

    func resume() { calls.append(.resume) }

    func reset() { calls.append(.reset) }

    func stop() async {
        if holdsStops { await withCheckedContinuation { heldStops.append($0) } }
        calls.append(.stop)
        current.state = .stopped
        current.framesPerSecond = 0
        publish()
        for stream in streams { stream.finish() }
        streams = []
    }

    func snapshots() -> AsyncStream<ConsoleSessionSnapshot> {
        calls.append(.snapshots)
        let (stream, continuation) = AsyncStream.makeStream(of: ConsoleSessionSnapshot.self)
        continuation.yield(current)
        streams.append(continuation)
        return stream
    }

    /// Sends frame `frame`, the shell reached or not, as the session does each frame: the program
    /// given at power-on is pending until the shell is reached.
    func run(to frame: Int, reachedShell: Bool = false) {
        current = ConsoleSessionSnapshot(
            state: .running, frame: frame, framesPerSecond: 60, reachedShell: reachedShell,
            bootIsPending: exe != nil && !reachedShell
        )
        publish()
    }

    private func publish() {
        for stream in streams { stream.yield(current) }
    }

    /// No account of the session for a failed expectation: its BIOS's 512 KB would take seconds to print.
    nonisolated var customMirror: Mirror {
        Mirror(self, children: [:])
    }
}

/// What happened, in order, across a session and the closures a test gives: whether the player's
/// session was powered on before the run was handed on.
// @unchecked: `events` is read and written only under `lock`.
final class EventLog: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [String] = []

    /// Notes `event`.
    func note(_ event: String) { lock.withLock { events.append(event) } }

    /// Everything noted, in order.
    var noted: [String] { lock.withLock { events } }
}

/// A mark a task sets on the main actor, to show it ran.
@MainActor
final class Ran {
    var isSet = false
}

/// Whether another screen's sheet covers the library, as a test sets it: the app's BIOS check and pane.
@MainActor
final class Cover {
    var isOn = false
}

/// What a job handed on, as the closures a test gives note it on the main actor: the runs handed on for the
/// player, the libraries a played game or an added one left, and the BIOS records kept again.
@MainActor
final class Handed {
    var runs: [GameRun] = []
    var libraries: [Library] = []
    var moved: [BIOSRecord] = []
}

// MARK: - Made-up files and games

/// 512 KB of made-up bytes, built in code: never a real BIOS.
let biosImage = (0..<524_288).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) }

/// A made-up PS-EXE built in code: the "PS-X EXE" header, its start and destination in RAM, and 2 KB of
/// code that does nothing. Never a real program.
let programImage: [UInt8] = {
    var bytes = [UInt8](repeating: 0, count: 0x1000)
    bytes.replaceSubrange(0..<8, with: Array("PS-X EXE".utf8))
    func word(_ value: UInt32, at offset: Int) {
        for index in 0..<4 { bytes[offset + index] = UInt8(truncatingIfNeeded: value >> (8 * index)) }
    }
    word(0x8001_0000, at: 0x10) // pc
    word(0x8001_0000, at: 0x18) // destination
    word(0x800, at: 0x1C) // size
    return bytes
}()

/// Where the tests' made-up files are: nothing is read from these paths.
enum Files {
    static let home = "/Users/you"
    static let bios = URL(fileURLWithPath: "/Users/you/Documents/Console/my-console-bios.bin")
    static let biosElsewhere = URL(fileURLWithPath: "/Volumes/Archive/Console/my-console-bios.bin")
    static let harbor = URL(fileURLWithPath: "/Users/you/Games/PS1/Harbor Lights (USA).cue")
    static let moonbase = URL(fileURLWithPath: "/Users/you/Games/PS1/Moonbase Courier.iso")
    static let tidepool = URL(fileURLWithPath: "/Users/you/Games/PS1/Tidepool/Tidepool.m3u")
    static let orchard = URL(fileURLWithPath: "/Users/you/Games/PS1/Glass Orchard (Europe).cue")
    static let gpuTest = URL(fileURLWithPath: "/Users/you/Games/Homebrew/gpu-test.exe")
    static let lantern = URL(fileURLWithPath: "/Users/you/Games/PS1/Lantern Street.cue")
    static let lanternMoved = URL(fileURLWithPath: "/Users/you/Games/PS1/Moved/Lantern Street.cue")
    static let notAProgram = URL(fileURLWithPath: "/Users/you/Games/Homebrew/readme.exe")
}

/// The tests' calendar: Gregorian, in UTC, so dates read the same on every machine.
let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    return calendar
}()

/// The moment `year`-`month`-`day` `hour`:`minute` in UTC.
func moment(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
    utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
}

/// The tests' now: Nov 22, 2026, 9:41 UTC.
let today = moment(2026, 11, 22, 9, 41)

/// The kept BIOS's record, its bookmark the made-up path.
let keptBIOS = BIOSRecord(
    fileName: "my-console-bios.bin", folder: "/Users/you/Documents/Console", size: 524_288, sha1: "",
    checked: moment(2026, 11, 20), bookmark: Data(Files.bios.path.utf8)
)

/// A game kept by the made-up file at `url`, its bookmark the path.
func game(
    _ url: URL, size: Int = 1_000, added: Date = moment(2026, 11, 14), played: Date? = nil, name: String? = nil,
    tracks: [String] = [], discs: [String] = []
) -> GameRecord {
    GameRecord(
        fileName: url.lastPathComponent, folder: url.deletingLastPathComponent().path,
        format: GameFormat(fileName: url.lastPathComponent) ?? .unknown(url.pathExtension), size: size, added: added,
        lastPlayed: played, name: name, bookmark: Data(url.path.utf8), tracks: tracks, discs: discs
    )
}

/// The design's sample library at the Today level, by made-up paths: three discs, a PS-EXE and a disc
/// whose file a test can take away.
func sampleGames() -> [GameRecord] {
    [
        game(Files.harbor, size: 512_340_096, played: moment(2026, 11, 22, 9, 30), tracks: ["Harbor Lights (USA) (Track 1).bin", "Harbor Lights (USA) (Track 2).bin"]),
        game(Files.moonbase, size: 487_915_520, played: moment(2026, 11, 21, 21, 10)),
        game(Files.tidepool, size: 1_953_021_952, added: moment(2026, 11, 12), played: moment(2026, 11, 12), discs: ["Tidepool (Disc 1).cue", "Tidepool (Disc 2).cue", "Tidepool (Disc 3).cue"]),
        game(Files.orchard, size: 398_458_880, tracks: ["Glass Orchard (Europe).bin"]),
        game(Files.gpuTest, size: 34_816, added: moment(2026, 11, 18), played: moment(2026, 11, 18)),
        game(Files.lantern, size: 402_653_184, added: moment(2026, 10, 2), played: moment(2026, 10, 30), tracks: ["Lantern Street.bin"]),
    ]
}

/// Storage holding the sample library, the BIOS and every file, the program's a real PS-EXE's bytes.
func sampleStorage(games: [GameRecord] = sampleGames()) -> MemoryStorage {
    var files: [URL: [UInt8]] = [Files.bios: biosImage, Files.gpuTest: programImage]
    for url in [Files.harbor, Files.moonbase, Files.tidepool, Files.orchard, Files.lantern] { files[url] = [1, 2, 3] }
    return MemoryStorage(library: Library(bios: keptBIOS, games: games), files: files)
}

// MARK: - A folder of games, built in a Sandbox

/// A folder of games as a person might keep them, built in `sandbox` from made-up files of a few bytes —
/// tiny cue sheets and playlists, never a disc image — with a file that isn't a game. Its games are the
/// five `foundGames` name: a .cue's .bin tracks and an .m3u's discs come with them.
func makeGames(in sandbox: Sandbox) throws -> URL {
    try sandbox.write("FILE \"Glass Orchard (Europe).bin\" BINARY\n  TRACK 01 MODE2/2352\n", to: "Games/PS1/Glass Orchard (Europe).cue")
    try sandbox.write(Data(repeating: 1, count: 1_000), to: "Games/PS1/Glass Orchard (Europe).bin")
    try sandbox.write("FILE \"Harbor Lights (USA) (Track 1).bin\" BINARY\nFILE \"Harbor Lights (USA) (Track 2).bin\" BINARY\n", to: "Games/PS1/Harbor Lights (USA).cue")
    try sandbox.write(Data(repeating: 2, count: 3_000), to: "Games/PS1/Harbor Lights (USA) (Track 1).bin")
    try sandbox.write(Data(repeating: 3, count: 500), to: "Games/PS1/Harbor Lights (USA) (Track 2).bin")
    try sandbox.write(Data(repeating: 4, count: 2_048), to: "Games/PS1/Moonbase Courier.iso")
    try sandbox.write("#EXTM3U\nTidepool (Disc 1).cue\nTidepool (Disc 2).iso\n", to: "Games/PS1/Tidepool/Tidepool.m3u")
    try sandbox.write("FILE \"Tidepool (Disc 1).bin\" BINARY\n", to: "Games/PS1/Tidepool/Tidepool (Disc 1).cue")
    try sandbox.write(Data(repeating: 5, count: 4_000), to: "Games/PS1/Tidepool/Tidepool (Disc 1).bin")
    try sandbox.write(Data(repeating: 6, count: 6_000), to: "Games/PS1/Tidepool/Tidepool (Disc 2).iso")
    try sandbox.write(Data(programImage), to: "Games/Homebrew/gpu-test.exe")
    try sandbox.write("Notes about the homebrew.", to: "Games/Homebrew/readme.txt")
    return sandbox.url("Games")
}

/// The games `makeGames(in:)` builds, as the scan finds them, by their paths below its folder.
let foundGames = [
    "Homebrew/gpu-test.exe",
    "PS1/Glass Orchard (Europe).cue",
    "PS1/Harbor Lights (USA).cue",
    "PS1/Moonbase Courier.iso",
    "PS1/Tidepool/Tidepool.m3u",
]

// MARK: - Waiting, bounded

/// Waits on the main actor until `condition` holds, for up to two seconds: the view-models hear the
/// session and the files on tasks of their own. True once it holds, false if it never did.
@MainActor
func eventually(_ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while !condition() {
        guard ContinuousClock.now < deadline else { return false }
        try? await Task.sleep(for: .milliseconds(1))
    }
    return true
}

/// Waits until `session` is followed, for up to two seconds.
func followed(_ session: FakePowerSession) async -> Bool {
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while await !session.isFollowed {
        guard ContinuousClock.now < deadline else { return false }
        try? await Task.sleep(for: .milliseconds(1))
    }
    return true
}

/// Waits until `session` holds `count` power-ons, for up to two seconds.
func holding(_ count: Int, _ session: FakePowerSession) async -> Bool {
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while await session.heldCount < count {
        guard ContinuousClock.now < deadline else { return false }
        try? await Task.sleep(for: .milliseconds(1))
    }
    return true
}

/// Waits until `session` holds `count` stops, for up to two seconds.
func holdingStops(_ count: Int, _ session: FakePowerSession) async -> Bool {
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while await session.heldStopCount < count {
        guard ContinuousClock.now < deadline else { return false }
        try? await Task.sleep(for: .milliseconds(1))
    }
    return true
}

/// Waits until `session` has recorded `count` calls of `call`, for up to two seconds.
func recorded(_ count: Int, _ call: FakePowerSession.Call, _ session: FakePowerSession) async -> Bool {
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while await session.controls.count(where: { $0 == call }) < count {
        guard ContinuousClock.now < deadline else { return false }
        try? await Task.sleep(for: .milliseconds(1))
    }
    return true
}

/// Waits until `storage` holds `count` calls at its gate, for up to two seconds.
func waiting(_ count: Int, _ storage: MemoryStorage) async -> Bool {
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while storage.waitingCalls < count {
        guard ContinuousClock.now < deadline else { return false }
        try? await Task.sleep(for: .milliseconds(1))
    }
    return true
}

/// Whether the library's looks, adds and locates and both its jobs have settled within two seconds:
/// false, and the test failing instead of hanging, when they never do.
@MainActor
func settled(_ library: LibraryViewModel) async -> Bool {
    await finishes { await library.settled() }
}

/// Whether the scan has settled within two seconds.
@MainActor
func settled(_ scan: ScanViewModel) async -> Bool {
    await finishes { await scan.settled() }
}

/// Whether the opening job and every stop it sent have settled within two seconds.
@MainActor
func settled(_ opening: OpeningViewModel) async -> Bool {
    await finishes { await opening.settled() }
}

/// Whether `work` finishes within two seconds. It runs on a task of its own, left behind if it never
/// finishes, so the waiting can end.
@MainActor
private func finishes(_ work: @escaping @MainActor () async -> Void) async -> Bool {
    let done = Flag()
    Task { @MainActor in
        await work()
        done.isSet = true
    }
    return await eventually { done.isSet }
}

/// A mark the main actor sets and reads.
@MainActor
private final class Flag {
    var isSet = false
}
