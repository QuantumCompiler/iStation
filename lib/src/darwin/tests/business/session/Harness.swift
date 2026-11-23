// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import BusinessSession
import Foundation
import SupportMIPS

// MARK: - Images built in code: never Sony's BIOS, never a game
//
// `bytes`, `image(of:size:)`, `halt`, `printing` and `storing` are SupportMIPS's, shared with the
// PS1 console's tests.

/// A 512 KB BIOS image with `program` at the reset vector.
func makeBIOS(_ program: [UInt32]) -> [UInt8] {
    image(of: program, size: PS1Bus.biosSize)
}

/// The shell's address, where a BIOS hands over to its shell (psx-spx).
let shellAddress: UInt32 = 0x8003_0000

/// A BIOS that prints `banner`, copies a stand-in shell that loops at 0x80030000 there and jumps to it:
/// it reaches its shell in its first frame.
func shellBIOS(printing banner: String = "") -> [UInt8] {
    makeBIOS(printing(banner) + storing(halt, at: shellAddress) + [MIPS.lui(t0, 0x8003), MIPS.jr(t0), MIPS.nop] + halt)
}

/// A BIOS that prints `banner` and never reaches its shell.
func stuckBIOS(printing banner: String = "") -> [UInt8] {
    makeBIOS(printing(banner) + halt)
}

/// A BIOS that calls its own B-function table at 0xB0 with putchar (B(3Dh)) and "A", through a stand-in
/// table it copies there that only returns: heard only when putchar is captured.
func putcharBIOS() -> [UInt8] {
    makeBIOS(storing([MIPS.jr(ra), MIPS.nop], at: 0xB0) + [
        MIPS.ori(a0, zero, Int(UInt8(ascii: "A"))), MIPS.ori(t2, zero, 0xB0), MIPS.jalr(ra, t2), MIPS.ori(t1, zero, 0x3D),
    ] + halt)
}

/// A BIOS image of the wrong size: 1,000 bytes, not 512 KB.
let wrongSizeBIOS = [UInt8](repeating: 0, count: 1000)

/// A PS-EXE that prints "OK" and stops, loaded and started at 0x80010000, the PS-EXE convention.
let okEXE = PSEXE(pc: 0x8001_0000, destination: 0x8001_0000, text: bytes(printing("OK") + halt))

// MARK: - A clock the test moves

/// A clock that moves only when a test moves it, so a session's pacing is exact and nothing waits on
/// real time: `sleep(until:)` returns once `advance(to:)` reaches its deadline, and throws when its task
/// is cancelled.
final class ManualClock: Clock, @unchecked Sendable {
    /// A moment on this clock: how far it has moved since it was made.
    struct Instant: InstantProtocol {
        var offset: Swift.Duration

        func advanced(by duration: Swift.Duration) -> Instant { Instant(offset: offset + duration) }
        func duration(to other: Instant) -> Swift.Duration { other.offset - offset }
        static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
    }

    private typealias Sleeper = (deadline: Instant, continuation: CheckedContinuation<Void, any Error>)

    // Unchecked Sendable: every field below is read and written under `lock` only.
    private let lock = NSLock()
    private var current = Instant(offset: .zero)
    private var sleepers: [Int: Sleeper] = [:]
    private var cancelledBeforeSleeping: Set<Int> = []
    private var lastID = 0

    var now: Instant { lock.withLock { current } }
    var minimumResolution: Swift.Duration { .zero }

    /// How many sleepers wait for an instant the clock hasn't reached.
    var sleeperCount: Int { lock.withLock { sleepers.count } }

    /// The earliest instant a sleeper waits for; nil when none waits.
    var nextDeadline: Instant? { lock.withLock { sleepers.values.map(\.deadline).min() } }

    func sleep(until deadline: Instant, tolerance: Swift.Duration? = nil) async throws {
        let id = lock.withLock { lastID += 1; return lastID }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let outcome: Result<Void, any Error>? = lock.withLock {
                    if cancelledBeforeSleeping.remove(id) != nil { return .failure(CancellationError()) }
                    if deadline <= current { return .success(()) }
                    sleepers[id] = (deadline, continuation)
                    return nil
                }
                if let outcome { continuation.resume(with: outcome) }
            }
        } onCancel: {
            let sleeper = lock.withLock {
                guard let sleeper = sleepers.removeValue(forKey: id) else {
                    cancelledBeforeSleeping.insert(id)
                    return nil as Sleeper?
                }
                return sleeper
            }
            sleeper?.continuation.resume(throwing: CancellationError())
        }
    }

    /// Moves the clock to `instant`, never back, waking every sleeper whose deadline it reaches.
    func advance(to instant: Instant) {
        let woken = lock.withLock {
            current = max(current, instant)
            let due = sleepers.filter { $0.value.deadline <= current }
            for id in due.keys { sleepers.removeValue(forKey: id) }
            return due.values.map(\.continuation)
        }
        for continuation in woken { continuation.resume() }
    }
}

/// Moves a manual clock a sixtieth of a second at a time, counted from when the session's frames started
/// (its power-on, resume or reset), and waits for the session's frame after each tick.
struct Ticks {
    let clock: ManualClock
    private(set) var start: ManualClock.Instant
    private(set) var count = 0

    init(_ clock: ManualClock) {
        self.clock = clock
        start = clock.now
    }

    /// Counts again from now: the session's frames started again.
    mutating func restart() {
        start = clock.now
        count = 0
    }

    /// The instant `ticks` sixtieths of a second after the start.
    func instant(_ ticks: Int) -> ManualClock.Instant { start.advanced(by: .seconds(ticks) / 60) }

    /// Moves the clock `ticks` sixtieths on, one at a time, each time waiting until the session has run
    /// the frame it brings; false when one didn't come within the timeout.
    mutating func run(_ ticks: Int = 1, _ session: ConsoleSession<ManualClock>) async -> Bool {
        for _ in 0..<ticks {
            let frame = await session.snapshot.frame
            count += 1
            clock.advance(to: instant(count))
            guard await eventually(session, { $0.frame > frame }) != nil else { return false }
        }
        return true
    }
}

// MARK: - Waiting, always with a timeout

/// How long a test waits, in real time, for what it expects before failing instead of hanging.
let timeout = Duration.seconds(5)

/// The session's snapshot once `condition` holds, or nil after `timeout` of real time.
func eventually<SessionClock: Clock>(
    _ session: ConsoleSession<SessionClock>, _ condition: (ConsoleSessionSnapshot) -> Bool
) async -> ConsoleSessionSnapshot? where SessionClock.Duration == Duration {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    repeat {
        let snapshot = await session.snapshot
        if condition(snapshot) { return snapshot }
        try? await Task.sleep(for: .milliseconds(1))
    } while ContinuousClock.now < deadline
    return nil
}

/// True once `condition` holds, false after `timeout` of real time.
func eventually(_ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    repeat {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(1))
    } while ContinuousClock.now < deadline
    return false
}

/// The snapshots a stream gives, kept under a lock: the reader appends, the test reads.
final class SnapshotLog: @unchecked Sendable {
    // Unchecked Sendable: `seen` is read and written under `lock` only.
    private let lock = NSLock()
    private var seen: [ConsoleSessionSnapshot] = []

    func append(_ snapshot: ConsoleSessionSnapshot) { lock.withLock { seen.append(snapshot) } }

    var all: [ConsoleSessionSnapshot] { lock.withLock { seen } }
}

/// Reads every snapshot `stream` gives, from the moment it is made, until the stream finishes.
final class Collector: Sendable {
    private let log: SnapshotLog
    private let task: Task<Void, Never>

    init(_ stream: AsyncStream<ConsoleSessionSnapshot>) {
        let log = SnapshotLog()
        self.log = log
        task = Task {
            for await snapshot in stream { log.append(snapshot) }
        }
    }

    /// The latest snapshot read so far; nil before the first.
    var latest: ConsoleSessionSnapshot? { log.all.last }

    /// Every snapshot read, once the stream has finished; nil, and the reading stopped, when it hasn't
    /// finished within `timeout`.
    func collected() async -> [ConsoleSessionSnapshot]? {
        let task = self.task
        let finished = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await task.value
                return true
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return false
            }
            let first = await group.next() ?? false
            task.cancel()
            group.cancelAll()
            return first
        }
        return finished ? log.all : nil
    }
}
