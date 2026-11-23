// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import BusinessSession
import DataLibrary
import Foundation
@testable import PresentationBIOS

/// A library and its files held in memory, as the tests script them: files by URL, a bookmark that is
/// the file's path, files a test moves (their bookmarks then stale), failures a test plants, and every
/// call in the order made. Nothing touches a file.
final class FakeStorage: BIOSStorage, @unchecked Sendable {
    /// One call the view-models made.
    enum Call: Equatable, Sendable {
        case keptBIOS, keep, bookmark(String), resolve, size(String), bytes(String)
    }

    /// The calls a test makes fail, and with what.
    struct Failures {
        var bookmark: KeptFileError?
        var resolve: KeptFileError?
        var size: KeptFileError?
        var bytes: KeptFileError?
        var keep: LibraryStoreError?
        var load: LibraryStoreError?
    }

    private let lock = NSLock()
    private var record: BIOSRecord?
    private var files: [String: [UInt8]] = [:]
    private var moves: [String: URL] = [:]
    private var log: [Call] = []
    private var planted = Failures()

    /// A library keeping `record`, holding `files`.
    init(record: BIOSRecord? = nil, files: [URL: [UInt8]] = [:]) {
        self.record = record
        for (url, bytes) in files { self.files[url.path] = bytes }
    }

    // MARK: What a test sets and reads

    /// The BIOS the library keeps now.
    var kept: BIOSRecord? { lock.withLock { record } }
    /// Every call, in order.
    var calls: [Call] { lock.withLock { log } }
    /// How many times the file at `url` was read whole.
    func reads(of url: URL) -> Int { calls.count { $0 == .bytes(url.path) } }

    /// Puts `bytes` at `url`.
    func put(_ bytes: [UInt8], at url: URL) { lock.withLock { files[url.path] = bytes } }

    /// Moves the file at `from` to `to`: a bookmark to `from` then leads to `to`, stale.
    func move(_ from: URL, to: URL) {
        lock.withLock {
            files[to.path] = files.removeValue(forKey: from.path)
            moves[from.path] = to
        }
    }

    /// Makes the calls `failures` names fail.
    func fail(_ failures: Failures) { lock.withLock { planted = failures } }

    // MARK: BIOSStorage

    func keptBIOS() throws -> BIOSRecord? {
        try lock.withLock {
            log.append(.keptBIOS)
            if let failure = planted.load { throw failure }
            return record
        }
    }

    func keep(_ record: BIOSRecord) throws {
        try lock.withLock {
            log.append(.keep)
            if let failure = planted.keep { throw failure }
            self.record = record
        }
    }

    func bookmark(for url: URL) throws -> Data {
        try lock.withLock {
            log.append(.bookmark(url.path))
            if let failure = planted.bookmark { throw failure }
            guard files[url.path] != nil else { throw KeptFileError.cannotBookmark(path: url.path, reason: "No such file.") }
            return Data(url.path.utf8)
        }
    }

    func resolve(_ bookmark: Data) throws -> KeptFile.Resolved {
        try lock.withLock {
            log.append(.resolve)
            if let failure = planted.resolve { throw failure }
            let path = String(decoding: bookmark, as: UTF8.self)
            if let moved = moves[path] { return KeptFile.Resolved(url: moved, isStale: true) }
            guard files[path] != nil else { throw KeptFileError.cannotResolve(reason: "No such file.") }
            return KeptFile.Resolved(url: URL(fileURLWithPath: path), isStale: false)
        }
    }

    func size(of url: URL) throws -> Int {
        try lock.withLock {
            log.append(.size(url.path))
            if let failure = planted.size { throw failure }
            guard let bytes = files[url.path] else { throw KeptFileError.cannotRead(path: url.path, reason: "No such file.") }
            return bytes.count
        }
    }

    func bytes(of url: URL) throws -> [UInt8] {
        try lock.withLock {
            log.append(.bytes(url.path))
            if let failure = planted.bytes { throw failure }
            guard let bytes = files[url.path] else { throw KeptFileError.cannotRead(path: url.path, reason: "No such file.") }
            return bytes
        }
    }
}

/// `FakeStorage` whose whole-file reads wait until the test lets them go — for two seconds at most, so
/// a test that forgets can't hang — so a Stop can land while a file is read.
final class GatedStorage: BIOSStorage, @unchecked Sendable {
    /// The storage every call goes on to.
    let inner: FakeStorage
    private let gate = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var waiting = 0

    /// `inner`, its reads gated.
    init(_ inner: FakeStorage) {
        self.inner = inner
    }

    /// How many reads wait at the gate.
    var waitingReads: Int { lock.withLock { waiting } }

    /// Lets one waiting read go on.
    func letGo() { gate.signal() }

    func keptBIOS() throws -> BIOSRecord? { try inner.keptBIOS() }

    func keep(_ record: BIOSRecord) throws { try inner.keep(record) }

    func bookmark(for url: URL) throws -> Data { try inner.bookmark(for: url) }

    func resolve(_ bookmark: Data) throws -> KeptFile.Resolved { try inner.resolve(bookmark) }

    func size(of url: URL) throws -> Int { try inner.size(of: url) }

    func bytes(of url: URL) throws -> [UInt8] {
        lock.withLock { waiting += 1 }
        _ = gate.wait(timeout: .now() + 2)
        lock.withLock { waiting -= 1 }
        return try inner.bytes(of: url)
    }
}

/// A console session the tests drive: powering on takes a BIOS's size and refuses another as the
/// console does, then runs nothing until a test sends the frames it wants seen; stop finishes every
/// stream with the stopped snapshot. It records every call, and notes each power-on in `log` when given
/// one, so a test can see what came before what. A test can hold power-ons or stops where they are,
/// after the call is recorded and before it takes effect, so a Stop can land while one is under way.
actor FakePowerSession: ConsoleSessionPowerControls {
    /// One call made of the session.
    enum Call: Equatable, Sendable {
        case powerOn(bytes: Int, exe: Bool), pause, resume, reset, stop, snapshots
    }

    private(set) var calls: [Call] = []
    private(set) var current = ConsoleSessionSnapshot()
    /// The bytes the session was last powered on with.
    private(set) var bios: [UInt8] = []
    private var streams: [AsyncStream<ConsoleSessionSnapshot>.Continuation] = []
    private let log: EventLog?
    private var holdsPowerOns = false
    private var holdsStops = false
    private var held: [CheckedContinuation<Void, Never>] = []

    /// A session, powered off, noting its power-ons in `log`.
    init(log: EventLog? = nil) {
        self.log = log
    }

    /// The calls, without the snapshot streams.
    var controls: [Call] { calls.filter { $0 != .snapshots } }

    /// How many power-ons and stops wait to be let go.
    var heldCount: Int { held.count }

    /// Holds every power-on from now, once it has taken a BIOS's size, until `letGo()`.
    func holdPowerOns() { holdsPowerOns = true }

    /// Holds every stop from now, once it is recorded, until `letGo()`.
    func holdStops() { holdsStops = true }

    /// Lets every held power-on and stop go on, in the order they came, and holds no more.
    func letGo() {
        holdsPowerOns = false
        holdsStops = false
        let waiting = held
        held = []
        for continuation in waiting { continuation.resume() }
    }

    var snapshot: ConsoleSessionSnapshot { current }

    func powerOn(bios: [UInt8], exe: PSEXE?) async throws(PS1Error) {
        calls.append(.powerOn(bytes: bios.count, exe: exe != nil))
        guard bios.count == PS1Bus.biosSize else { throw .biosSize(bios.count) }
        if holdsPowerOns { await withCheckedContinuation { held.append($0) } }
        self.bios = bios
        log?.note("powered on")
        current = ConsoleSessionSnapshot(state: .running)
        publish()
    }

    func pause() { calls.append(.pause) }

    func resume() { calls.append(.resume) }

    func reset() { calls.append(.reset) }

    func stop() async {
        calls.append(.stop)
        if holdsStops { await withCheckedContinuation { held.append($0) } }
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

    /// Sends frame `frame`, the shell reached or not, as the session does each frame.
    func run(to frame: Int, reachedShell: Bool = false) {
        current = ConsoleSessionSnapshot(state: .running, frame: frame, framesPerSecond: 60, reachedShell: reachedShell)
        publish()
    }

    /// Whether a check follows the session's frames now.
    var isFollowed: Bool { !streams.isEmpty }

    private func publish() {
        for stream in streams { stream.yield(current) }
    }
}

/// What happened, in order, across a session and the closures a test gives: whether the player's
/// session was powered on before the run was handed on.
final class EventLog: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [String] = []

    /// Notes `event`.
    func note(_ event: String) { lock.withLock { events.append(event) } }

    /// Everything noted, in order.
    var noted: [String] { lock.withLock { events } }
}

/// 512 KB of made-up bytes, built in code: never a real BIOS.
let biosImage = (0..<524_288).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) }

/// Where the tests' files are, by made-up paths: nothing is read from them.
enum Files {
    static let home = "/Users/you"
    static let bios = URL(fileURLWithPath: "/Users/you/Documents/Console/my-console-bios.bin")
    static let backup = URL(fileURLWithPath: "/Users/you/Downloads/bios-backup.zip")
    static let copy = URL(fileURLWithPath: "/Users/you/Documents/Console/bios-copy.bin")
    static let elsewhere = URL(fileURLWithPath: "/Volumes/Archive/Console/my-console-bios.bin")
}

/// Waits on the main actor until `condition` holds, for up to two seconds: the view-models hear the
/// session on tasks of their own. True once it holds, false if it never did.
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

/// Waits until `session`'s calls, the snapshot streams left out, satisfy `condition`, for up to two
/// seconds.
func controls(
    of session: FakePowerSession, reach condition: @Sendable ([FakePowerSession.Call]) -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while await !condition(session.controls) {
        guard ContinuousClock.now < deadline else { return false }
        try? await Task.sleep(for: .milliseconds(1))
    }
    return true
}

/// Waits until `session` holds `count` power-ons and stops, for up to two seconds.
func holding(_ count: Int, _ session: FakePowerSession) async -> Bool {
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while await session.heldCount < count {
        guard ContinuousClock.now < deadline else { return false }
        try? await Task.sleep(for: .milliseconds(1))
    }
    return true
}

/// Whether the check has settled — its work and every stop it sent finished — within two seconds:
/// false, and the test failing instead of hanging, when it never does.
@MainActor
func settled(_ check: BIOSCheckViewModel) async -> Bool {
    await finishes { await check.settled() }
}

/// Whether the pane's last Run the BIOS has finished within two seconds.
@MainActor
func settled(_ pane: BIOSPaneViewModel) async -> Bool {
    await finishes { await pane.settled() }
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
